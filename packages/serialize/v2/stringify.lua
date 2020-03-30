local datalist = require 'datalist'

local out

local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        if type(k) == "string" then
            sort[#sort+1] = k
        end
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

local function copytable(t)
    local res = {}
    for k, v in pairs(t) do
        res[k] = v
    end
    return res
end

local function isMultipe(v)
    if type(v) == "table" and v[1] ~= nil then
        for k in pairs(v) do
            if type(k) == "string" then
                return true
            end
        end
    end
    return false
end

local function isArray(v)
    return v[1] ~= nil
end

local function indent(n)
    return ("  "):rep(n)
end

local function convertreal(v)
    local g = ('%.16g'):format(v)
    if tonumber(g) == v then
        return g
    end
    return ('%.17g'):format(v)
end

local PATTERN <const> = "%a%d/%-_."
local PATTERN <const> = "^["..PATTERN.."]["..PATTERN.."]*$"

local function stringify_basetype(v)
    local t = type(v)
    if t == 'number' then
        if math.type(v) == "integer" then
            return ('%d'):format(v)
        else
            return convertreal(v)
        end
    elseif t == 'string' then
        if v:match(PATTERN) then
            return v
        else
            return datalist.quote(v)
        end
    elseif t == 'boolean'then
        if v then
            return 'true'
        else
            return 'false'
        end
    end
    error('invalid type:'..t)
end

local stringify_value

local function stringify_array_simple(n, prefix, t)
    local s = {}
    for _, v in ipairs(t) do
        s[#s+1] = stringify_basetype(v)
    end
    out[#out+1] = indent(n)..prefix.."{"..table.concat(s, ", ").."}"
end

local function stringify_array_map(n, t)
    for _, tt in ipairs(t) do
        out[#out+1] = indent(n).."---"
        for k, v in sortpairs(tt) do
            stringify_value(n, k..":", v)
        end
    end
end

local function stringify_array_array(n, t)
    local first_value = t[1][1]
    if type(first_value) ~= "table" then
        for _, tt in ipairs(t) do
            stringify_array_simple(n, "", tt)
        end
        return
    end
    if isArray(first_value) then
        for _, tt in ipairs(t) do
            out[#out+1] = indent(n).."---"
            stringify_array_array(n+1, tt)
        end
    else
        for _, tt in ipairs(t) do
            out[#out+1] = indent(n).."---"
            stringify_array_map(n+1, tt)
        end
    end
end

local function stringify_array(n, prefix, t)
    local first_value = t[1]
    if type(first_value) ~= "table" then
        stringify_array_simple(n, prefix.." ", t)
        return
    end
    out[#out+1] = indent(n)..prefix
    if isArray(first_value) then
        stringify_array_array(n+1, t)
        return
    end
    stringify_array_map(n+1, t)
end

local function stringify_map(n, prefix, t)
    out[#out+1] = indent(n)..prefix
    n = n + 1
    for k, v in sortpairs(t) do
        stringify_value(n, k..":", v)
    end
end

function stringify_value(n, prefix, v)
    if type(v) == "table" then
        local first_value = next(v)
        if first_value == nil then
            out[#out+1] = indent(n)..prefix..' {}'
            return
        end
        if type(first_value) == "number" then
            stringify_array(n, prefix, v)
        else
            stringify_map(n, prefix, v)
        end
        return
    end
    out[#out+1] = indent(n)..prefix.." "..stringify_basetype(v)
end

local function stringify_component(prefix, v)
    if isMultipe(v) then
        stringify_map(0, prefix, v)
        for _, vv in ipairs(v) do
            stringify_map(0, prefix, vv)
        end
    else
        stringify_value(0, prefix, v)
    end
end

local function stringify_policy(policies)
    local t = copytable(policies)
    table.sort(t)
    for _, p in ipairs(t) do
        out[#out+1] = p
    end
end

local function stringify_dataset(dataset)
    for name, v in sortpairs(dataset) do
        stringify_component(name..':', v)
    end
end

local function stringify_entity(policies, dataset)
    out = {}
    out[#out+1] = '---------'
    stringify_policy(policies)
    out[#out+1] = '---------'
    stringify_dataset(dataset)
    out[#out+1] = ''
    return table.concat(out, '\n')
end

local function stringify_map_(data)
    out = {}
    for k, v in sortpairs(data) do
        stringify_value(0, k..":", v)
    end
    return table.concat(out, '\n')
end

return {
    entity = stringify_entity,
    map = stringify_map_,
}
