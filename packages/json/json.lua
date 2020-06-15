local pairs = pairs
local type = type
local next = next
local error = error
local tonumber = tonumber
local tostring = tostring
local utf8_char = utf8.char
local table_concat = table.concat
local string_char = string.char
local string_byte = string.byte
local math_type = math.type
local setmetatable = setmetatable
local Inf = math.huge

local json = {}

json.null = function() end
json.object_mt = {}

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local encode_escape_map = {
    [ "\"" ] = "\\\"",
    [ "\\" ] = "\\\\",
    [ "/" ]  = "\\/",
    [ "\b" ] = "\\b",
    [ "\f" ] = "\\f",
    [ "\n" ] = "\\n",
    [ "\r" ] = "\\r",
    [ "\t" ] = "\\t",
}

local decode_escape_set = {}
local decode_escape_map = {}
for k, v in pairs(encode_escape_map) do
    decode_escape_map[v] = k
    decode_escape_set[string_byte(v, 2)] = true
end

local function encode_escape(c)
    return encode_escape_map[c] or ("\\u%04x"):format(c:byte())
end

local function encode_nil()
    return "null"
end

local function encode_null(val)
    if val == json.null then
        return "null"
    end
    error "cannot serialise function: type not supported"
end

local function encode_string(val)
    return '"' .. val:gsub('[%z\1-\31\127\\"/]', encode_escape) .. '"'
end

local function convertreal(v)
    local g = ('%.16g'):format(v)
    if tonumber(g) == v then
        return g
    end
    return ('%.17g'):format(v)
end

local function encode_number(val)
    if val ~= val or val <= -Inf or val >= Inf then
        error("unexpected number value '" .. tostring(val) .. "'")
    end
    return convertreal(val):gsub(',', '.')
end

local function encode_table(val, stack)
    local first_val = next(val)
    if first_val == nil then
        if getmetatable(val) == json.object_mt then
            return "{}"
        else
            return "[]"
        end
    elseif type(first_val) == 'number' then
        local max = 0
        for k in pairs(val) do
            if math_type(k) ~= "integer" then
                error("invalid table: mixed or invalid key types")
            end
            max = max > k and max or k
        end
        local res = {}
        stack = stack or {}
        if stack[val] then error("circular reference") end
        stack[val] = true
        for i = 1, max do
            res[#res+1] = encode(val[i], stack)
        end
        stack[val] = nil
        return "[" .. table_concat(res, ",") .. "]"
    else
        local res = {}
        stack = stack or {}
        if stack[val] then error("circular reference") end
        stack[val] = true
        for k, v in pairs(val) do
            if type(k) ~= "string" then
                error("invalid table: mixed or invalid key types")
            end
            res[#res+1] = encode_string(k) .. ":" .. encode(v, stack)
        end
        stack[val] = nil
        return "{" .. table_concat(res, ",") .. "}"
    end
end

local type_func_map = {
    [ "nil"      ] = encode_nil,
    [ "table"    ] = encode_table,
    [ "string"   ] = encode_string,
    [ "number"   ] = encode_number,
    [ "boolean"  ] = tostring,
    [ "function" ] = encode_null,
}

encode = function(val, stack)
    local t = type(val)
    local f = type_func_map[t]
    if f then
        return f(val, stack)
    end
    error("unexpected type '" .. t .. "'")
end

function json.encode(val)
    return encode(val)
end

-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local decode
local _buf
local _pos

local literal_map = {
    [ "true"  ] = true,
    [ "false" ] = false,
    [ "null"  ] = json.null,
}

local function next_word()
    local _, newpos, word, eol = _buf:find("([^ \t\r\n%]},]*)([ \t\r\n%]},]?)", _pos)
    if eol ~= "" then
        return word, newpos
    end
    return word, newpos + 1
end

local function next_byte()
    _pos = _buf:find("[^ \t\r\n]", _pos)
    if _pos then
        return string_byte(_buf, _pos)
    end
    _pos = #_buf + 1
end

local function getline(str, n)
    local line = 1
    local pos = 1
    while true do
        local f, _, nl1, nl2 = str:find('([\n\r])([\n\r]?)', pos)
        if not f then
            return line, n - pos + 1
        end
        local newpos = f + ((nl1 == nl2 or nl2 == '') and 1 or 2)
        if newpos > n then
            return line, n - pos + 1
        end
        pos = newpos
        line = line + 1
    end
end

local function decode_error(msg)
    error(("%s at line %d col %d"):format(msg, getline(msg, _pos)))
end

local function parse_unicode_escape(s)
    local n1 = tonumber(s:sub(3, 6),  16)
    local n2 = tonumber(s:sub(9, 12), 16)
    if n2 then
        return utf8_char((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
    else
        return utf8_char(n1)
    end
end

local function parse_string()
    local has_unicode_escape = false
    local has_surrogate_escape = false
    local has_escape = false
    local i = _pos
    while true do
        i = _buf:find('[\0-\31\\"]', i + 1)
        if not i then
            decode_error "expected closing quote for string"
        end
        local x = string_byte(_buf, i)
        if x < 32 then
            _pos = i
            decode_error "control character in string"
        end
        if x == 92 --[[ "\\" ]] then
            local nx = string_byte(_buf, i+1)
            if nx == 117 --[[ "u" ]] then
                local hex = _buf:sub(i+2, i+5)
                if not hex:match "%x%x%x%x" then
                    _pos = i
                    decode_error "invalid unicode escape in string"
                end
                if hex:match "^[dD][89aAbB]" then
                    if not _buf:sub(i+6, i+11):match '\\u%x%x%x%x' then
                        _pos = i
                        decode_error "missing low surrogate"
                    end
                    has_surrogate_escape = true
                    i = i + 11
                else
                    has_unicode_escape = true
                    i = i + 5
                end
            else
                if not decode_escape_set[nx] then
                    _pos = i
                    decode_error("invalid escape char '" .. string_char(nx) .. "' in string")
                end
                has_escape = true
                i = i + 1
            end
        elseif x == 34 --[[ '"' ]] then
            local s = _buf:sub(_pos + 1, i - 1)
            if has_surrogate_escape then
                s = s:gsub("\\u[dD][89aAbB]%x%x\\u%x%x%x%x", parse_unicode_escape)
            end
            if has_unicode_escape then
                s = s:gsub("\\u%x%x%x%x", parse_unicode_escape)
            end
            if has_escape then
                s = s:gsub("\\.", decode_escape_map)
            end
            _pos = i + 1
            return s
        end
    end
end

local function parse_number()
    local word, newpos = next_word()
    local n = tonumber(word)
    if not n or word:find '[^-+.%deE]' or word:match '^0[1-9]' then
        decode_error("invalid number '" .. word .. "'")
    end
    _pos = newpos
    return n
end

local function parse_literal()
    local word, newpos = next_word()
    local res = literal_map[word]
    if res == nil then
        decode_error("invalid literal '" .. word .. "'")
    end
    _pos = newpos
    return res
end

local function parse_array()
    _pos = _pos + 1
    if next_byte() == 93 --[[ "]" ]] then
        _pos = _pos + 1
        return {}
    end
    local res = {}
    local n = 0
    while true do
        n = n + 1
        res[n] = decode()
        local chr = next_byte()
        _pos = _pos + 1
        if chr == 93 --[[ "]" ]] then return res end
        if chr ~= 44 --[[ "," ]] then decode_error "expected ']' or ','" end
    end
end

local function parse_object()
    local res = {}
    _pos = _pos + 1
    while true do
        local chr = next_byte()
        if chr == 125 --[[ "}" ]] then
            _pos = _pos + 1
            break
        end
        if chr ~= 34 --[[ '"' ]] then
            decode_error "expected string for key"
        end
        local key = parse_string()
        if next_byte() ~= 58 --[[ ":" ]] then
            decode_error "expected ':' after key"
        end
        _pos = _pos + 1
        res[key] = decode()
        local chr = next_byte()
        _pos = _pos + 1
        if chr == 125 --[[ "}" ]] then break end
        if chr ~= 44 --[[ "," ]] then decode_error "expected '}' or ','" end
    end
    if next(res) == nil then
        setmetatable(res, json.object_mt)
    end
    return res
end

local char_func_map = {
    [ string_byte '"' ] = parse_string,
    [ string_byte "0" ] = parse_number,
    [ string_byte "1" ] = parse_number,
    [ string_byte "2" ] = parse_number,
    [ string_byte "3" ] = parse_number,
    [ string_byte "4" ] = parse_number,
    [ string_byte "5" ] = parse_number,
    [ string_byte "6" ] = parse_number,
    [ string_byte "7" ] = parse_number,
    [ string_byte "8" ] = parse_number,
    [ string_byte "9" ] = parse_number,
    [ string_byte "-" ] = parse_number,
    [ string_byte "t" ] = parse_literal,
    [ string_byte "f" ] = parse_literal,
    [ string_byte "n" ] = parse_literal,
    [ string_byte "[" ] = parse_array,
    [ string_byte "{" ] = parse_object,
}

decode = function()
    local chr = next_byte()
    local f = char_func_map[chr]
    if f then
        return f()
    end
    decode_error("unexpected character '" .. string_char(chr) .. "'")
end

function json.decode(str)
    if type(str) ~= "string" then
        error("expected argument of type string, got " .. type(str))
    end
    _buf = str
    _pos = 1
    local res = decode()
    if next_byte() ~= nil then
        decode_error "trailing garbage"
    end
    return res
end

return json
