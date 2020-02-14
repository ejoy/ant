local pairs = pairs
local type = type
local next = next
local error = error
local tonumber = tonumber
local utf8_char = utf8.char
local table_concat = table.concat
local string_char = string.char
local math_type = math.type
local Inf = math.huge

local json = {}

json.null = function() end

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
    [ "\\" ] = "\\\\",
    [ "/" ]  = "\\/",
    [ "\"" ] = "\\\"",
    [ "\b" ] = "\\b",
    [ "\f" ] = "\\f",
    [ "\n" ] = "\\n",
    [ "\r" ] = "\\r",
    [ "\t" ] = "\\t",
}

local escape_char_map_inv = { [ "\\/" ] = "/" }
for k, v in pairs(escape_char_map) do
    escape_char_map_inv[v] = k
end

local function escape_char(c)
    return escape_char_map[c] or ("\\u%04x"):format(c:byte())
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

local function encode_table(val, stack)
    local res = {}
    stack = stack or {}
    if stack[val] then error("circular reference") end
    stack[val] = true
    if next(val) == nil then
        local meta = getmetatable(val)
        if meta and meta.__name == 'json.object' then
            return "{}"
        else
            return "[]"
        end
    elseif type(next(val)) == 'number' then
        local max = 0
        for k in pairs(val) do
            if math_type(k) ~= "integer" then
                error("invalid table: mixed or invalid key types")
            end
            max = max > k and max or k
        end
        for i = 1, max do
            res[#res+1] = encode(val[i], stack)
        end
        stack[val] = nil
        return "[" .. table_concat(res, ",") .. "]"
    else
        for k, v in pairs(val) do
            if type(k) ~= "string" then
                error("invalid table: mixed or invalid key types")
            end
            res[#res+1] = encode(k, stack) .. ":" .. encode(v, stack)
        end
        stack[val] = nil
        return "{" .. table_concat(res, ",") .. "}"
    end
end

local function encode_string(val)
    return '"' .. val:gsub('[%z\1-\31\127\\"/]', escape_char) .. '"'
end

local function encode_number(val)
    if val ~= val or val <= -Inf or val >= Inf then
        error("unexpected number value '" .. tostring(val) .. "'")
    end
    return ("%.14g"):format(val):gsub(',', '.')
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

local escape_chars = {
    [ "\\" ] = true,
    [ "/" ] = true,
    [ '"' ] = true,
    [ "b" ] = true,
    [ "f" ] = true,
    [ "n" ] = true,
    [ "r" ] = true,
    [ "t" ] = true,
    [ "u" ] = true,
}

local literal_map = {
    [ "true"  ] = true,
    [ "false" ] = false,
    [ "null"  ] = json.null,
}

local function next_word()
    local f = _pos
    local idx = _buf:find("[ \t\r\n%]},]", _pos)
    _pos = idx and idx or (#_buf + 1)
    return _buf:sub(f, _pos - 1), f
end

local function next_nonspace()
    local idx = _buf:find("[^ \t\r\n]", _pos)
    _pos = idx and idx or (#_buf + 1)
end

local function decode_error(msg, idx)
    idx = idx or _pos
    local line_count = 1
    local col_count = 1
    for i = 1, idx - 1 do
        col_count = col_count + 1
        if _buf:sub(i, i) == "\n" then
            line_count = line_count + 1
            col_count = 1
        end
    end
    error(("%s at line %d col %d"):format(msg, line_count, col_count))
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
    local last
    for j = _pos + 1, #_buf do
        local x = _buf:byte(j)
        if x < 32 then
            decode_error("control character in string", j)
        end
        if last == 92 then -- "\\" (escape char)
            if x == 117 then -- "u" (unicode escape sequence)
                local hex = _buf:sub(j + 1, j + 5)
                if not hex:find("%x%x%x%x") then
                    decode_error("invalid unicode escape in string", j)
                end
                if hex:find("^[dD][89aAbB]") then
                    if not _buf:sub(j + 5, j + 10):match('\\u%x%x%x%x') then
                        decode_error("missing low surrogate", j)
                    end
                    has_surrogate_escape = true
                else
                    has_unicode_escape = true
                end
            else
                local c = string_char(x)
                if not escape_chars[c] then
                    decode_error("invalid escape char '" .. c .. "' in string", j)
                end
                has_escape = true
            end
            last = nil
        elseif x == 34 then -- '"' (end of string)
            local s = _buf:sub(_pos + 1, j - 1)
            if has_surrogate_escape then
                s = s:gsub("\\u[dD][89aAbB]..\\u....", parse_unicode_escape)
            end
            if has_unicode_escape then
                s = s:gsub("\\u....", parse_unicode_escape)
            end
            if has_escape then
                s = s:gsub("\\.", escape_char_map_inv)
            end
            _pos = j + 1
            return s
        else
            last = x
        end
    end
    decode_error("expected closing quote for string")
end

local function parse_number()
    local word, f = next_word()
    local n = tonumber(word)
    if not n or word:find '[^-+.%deE]' or word:match '^0[1-9]' then
        decode_error("invalid number '" .. word .. "'", f)
    end
    return n
end

local function parse_literal()
    local word, f = next_word()
    if literal_map[word] == nil then
        decode_error("invalid literal '" .. word .. "'", f)
    end
    return literal_map[word]
end

local function parse_array()
    _pos = _pos + 1
    next_nonspace()
    if _buf:sub(_pos, _pos) == "]" then
        _pos = _pos + 1
        return {}
    end
    local res = {}
    local n = 1
    while true do
        res[n] = decode()
        n = n + 1
        next_nonspace()
        local chr = _buf:sub(_pos, _pos)
        _pos = _pos + 1
        if chr == "]" then return res end
        if chr ~= "," then decode_error("expected ']' or ','") end
    end
end

local function parse_object()
    local res = {}
    _pos = _pos + 1
    while true do
        next_nonspace()
        if _buf:sub(_pos, _pos) == "}" then
            _pos = _pos + 1
            break
        end
        if _buf:sub(_pos, _pos) ~= '"' then
            decode_error("expected string for key")
        end
        local key = decode()
        next_nonspace()
        if _buf:sub(_pos, _pos) ~= ":" then
            decode_error("expected ':' after key")
        end
        _pos = _pos + 1
        next_nonspace()
        local val = decode()
        res[key] = val
        next_nonspace()
        local chr = _buf:sub(_pos, _pos)
        _pos = _pos + 1
        if chr == "}" then break end
        if chr ~= "," then decode_error("expected '}' or ','") end
    end
    if next(res) == nil then
        setmetatable(res, {__name = 'json.object'})
    end
    return res
end

local char_func_map = {
    [ '"' ] = parse_string,
    [ "0" ] = parse_number,
    [ "1" ] = parse_number,
    [ "2" ] = parse_number,
    [ "3" ] = parse_number,
    [ "4" ] = parse_number,
    [ "5" ] = parse_number,
    [ "6" ] = parse_number,
    [ "7" ] = parse_number,
    [ "8" ] = parse_number,
    [ "9" ] = parse_number,
    [ "-" ] = parse_number,
    [ "t" ] = parse_literal,
    [ "f" ] = parse_literal,
    [ "n" ] = parse_literal,
    [ "[" ] = parse_array,
    [ "{" ] = parse_object,
}

decode = function()
    local chr = _buf:sub(_pos, _pos)
    local f = char_func_map[chr]
    if f then
        return f()
    end
    decode_error("unexpected character '" .. chr .. "'")
end

function json.decode(str)
    if type(str) ~= "string" then
        error("expected argument of type string, got " .. type(str))
    end
    _buf = str
    _pos = 1
    next_nonspace()
    local res = decode()
    next_nonspace()
    if _pos <= #str then
        decode_error("trailing garbage")
    end
    return res
end

return json
