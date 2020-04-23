local datalist = require 'datalist'

local world
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
        assert(#v < 1000)
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
    elseif t == 'function' then
        return 'null'
    elseif t == 'userdata' then
        return "userdata" -- TODO
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
        if k:sub(1,1) ~= "_" then
            stringify_value(n, k..":", v)
        end
    end
end

function stringify_value(n, prefix, v)
    if type(v) == "table" or type(v) == "userdata" then
        local typename = world._typeclass[v]
        if typename then
            local tc = world:import_component(typename)
            if tc and tc.methodfunc and tc.methodfunc.save then
                return stringify_value(n, prefix.." $"..typename, tc.methodfunc.save(v))
            end
        end
    end
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

local function stringify_policy(n, policies)
    local t = copytable(policies)
    table.sort(t)
    for _, p in ipairs(t) do
        out[#out+1] = indent(n)..p
    end
end

local function stringify_dataset(n, dataset)
    for name, v in sortpairs(dataset) do
        stringify_value(n, name..':', v)
    end
end

local function stringify_entity(policies, dataset)
    out = {}
    out[#out+1] = 'policy:'
    stringify_policy(1, policies)
    out[#out+1] = 'data:'
    stringify_dataset(1, dataset)
    out[#out+1] = ''
    return table.concat(out, '\n')
end

local function entity(w, eid)
    world = w
    return stringify_entity(w._policies[eid], w[eid])
end

return {
    entity = entity,
}
