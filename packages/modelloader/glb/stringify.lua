local stringify_value

local pretty
local res
local indent

local function getindent()
    if pretty then
        return ("  "):rep(indent)
    end
    return ""
end

local function convertreal(v)
    local g = ('%.16g'):format(v)
    if tonumber(g) == v then
        return g
    end
    return ('%.17g'):format(v)
end

local function isarray(t)
    local k = next(t)
    if k == nil then
        -- empty table must be array
        return true
    end
    if type(k) == "string" then
        return false
    end
    assert(math.type(k) == "integer")
    return true
end

local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local function stringify_array(t)
    local max = 0
    for k in pairs(t) do
        if math.type(k) ~= "integer" then
            error("invalid table: mixed or invalid key types")
        end
        max = max > k and max or k
    end
    if max == 0 then
        res[#res+1] = getindent().."}"
        return "{"
    end
    indent = indent + 1
    for i = 1, max do
        local pos = #res+1
        res[pos] = false
        res[pos] = getindent()..stringify_value(t[i])
        res[#res] = res[#res] .. ","
    end
    indent = indent - 1
    res[#res] = res[#res]:sub(1,-2)
    res[#res+1] = getindent().."}"
    return "{"
end

local function stringify_key(v)
    if v:match "^[%a_][%w_]*$" then
        return v
    end
    return ("[%q]"):format(v)
end

local function stringify_object(t)
    local fmt = pretty and "%s = %s" or "%s=%s"
    indent = indent + 1
    for k, v in sortpairs(t) do
        if type(k) ~= "string" then
            error("invalid table: mixed or invalid key types")
        end
        local pos = #res+1
        res[pos] = false
        res[pos] = getindent()..fmt:format(stringify_key(k), stringify_value(v))
        res[#res] = res[#res] .. ","
    end
    indent = indent - 1
    res[#res] = res[#res]:sub(1,-2)
    res[#res+1] = getindent().."}"
    return "{"
end

function stringify_value(v)
    local t = type(v)
    if t == "nil" then
        return "nil"
    elseif t == "number" then
        if math.type(v) == "integer" then
            return ("%d"):format(v)
        end
        return convertreal(v)
    elseif t == "string" then
        return ("%q"):format(v)
    elseif t == "boolean" then
        return t and "true" or "false"
    elseif t == "table" then
        if isarray(v) then
            return stringify_array(v)
        end
        return stringify_object(v)
    else
        error("invalid type: "..t)
    end
end

local function stringify(v, p)
    pretty = p
    indent = 0
    res = {false}
    if pretty then
        res[1] = "return "..stringify_value(v)
        return table.concat(res, "\n")
    end
    res[1] = "return"..stringify_value(v)
    return table.concat(res)
end

return stringify
