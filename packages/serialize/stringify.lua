local datalist = require 'datalist'

local pool
local out
local stack
local typeinfo
local e_prefix
local c_prefix
local cid 

local function prefix(len)
    local n = #('%x'):format(len) + 1
    assert(n <= 7)
    e_prefix = 0xe*(1<<(4*n))
    c_prefix = 0xc*(1<<(4*(n+1)))
end

local function convertreal(v)
    local g = ('%g'):format(v)
    if tonumber(g) == v then
        return g
    end
    for i = 6, 20 do
        local ng = ('%%.%dg'):format(i):format(v)
        if tonumber(ng) == v then
            return ng
        end
    end
    return ('%a'):format(v)
end

local function stringify_basetype(name, v)
    if name == 'int' then
        return ('%d'):format(v)
    elseif name == 'real' then
        return convertreal(v)
    elseif name == 'string' then
        return datalist.quote(v)
    elseif name == 'boolean' then
        if v then
            return 'true'
        else
            return 'false'
        end
    end
    assert('unknown base type:'..name)
end

local function stringify_array_value(c, array, v)
    if c.type ~= 'primtype' then
        return stringify_array_value(typeinfo[c.type], array, v)
    end
    local n = array == 0 and #v or array
    local s = {}
    for i = 1, n do
        s[i] = stringify_basetype(c.name, v[i])
    end
    return '{'..table.concat(s, ',')..'}'
end

local function stringify_map_value(c, map, v)
    if c.type ~= 'primtype' then
        return stringify_map_value(typeinfo[c.type], map, v)
    end
    local s = {}
    for i = 1, #v do
        s[#s+1] = v[i][1]..':'..stringify_basetype(c.name, v[i][2])
    end
    return '{'..table.concat(s, ',')..'}'
end

local function stringify_value(c, v)
    assert(c.type)
    if c.array then
        return stringify_array_value(c, c.array, v)
    end
    if c.map then
        return stringify_map_value(c, c.map, v)
    end
    if c.type == 'primtype' then
        return stringify_basetype(c.name, v)
    end
    return stringify_value(typeinfo[c.type], v)
end

local function stringify_component_value(name, v)
    assert(typeinfo[name], "unknown type:" .. name)
    local c = typeinfo[name]
    if not c.ref then
        return stringify_value(c, v)
    end
    if not pool[v] then
        cid = cid + 1
        pool[v] = c_prefix + cid
        stack[#stack+1] = {c, v}
    end
    return ('*%x'):format(pool[v])
end

local stringify_component_ref

local function stringify_component_children(c, v)
    if not c.ref then
        return stringify_value(c, v)
    end
    if c.array then
        local n = c.array == 0 and #v or c.array
        for i = 1, n do
            out[#out+1] = '  ---'
            stringify_component_ref(typeinfo[c.type], v[i], 1)
        end
        return
    end
    if c.map then
        for i = 1, #v do
            out[#out+1] = ('  %s:'):format(v[i][1])
            stringify_component_ref(typeinfo[c.type], v[i][2], 2)
        end
        return
    end
    return stringify_component_value(c.type, v)
end

function stringify_component_ref(c, v, lv)
    assert(not c.type)
    for _, cv in ipairs(c) do
        if v[cv.name] ~= nil then
            if cv.ref and (cv.array or cv.map) then
                out[#out+1] = ('  '):rep(lv) .. ('%s:'):format(cv.name)
                stringify_component_children(cv, v[cv.name])
            else
                out[#out+1] = ('  '):rep(lv) .. ('%s:%s'):format(cv.name, stringify_component_children(cv, v[cv.name]))
            end
        end
    end
end

local function stringify_entity(e)
    for _, c in ipairs(e) do
        local k, v = c[1], c[2]
        out[#out+1] = ('%s:%s'):format(k, stringify_component_value(k, v))
    end

    while #stack ~= 0 do
        local c, v = stack[1][1], stack[1][2]
        table.remove(stack, 1)

        out[#out+1] = ('--- &%x'):format(pool[v])
        stringify_component_ref(c, v, 0)
    end
end

local function stringify(w, t)
    pool = {}
    out = {}
    stack = {}
    typeinfo = w.schema.map
    cid = 0
    prefix(#t)
    out[#out+1] = '---'
    for i in ipairs(t) do
        out[#out+1] = ('  --- *%x'):format(e_prefix + i)
    end
    for i, e in ipairs(t) do
        out[#out+1] = ('--- &%x'):format(e_prefix + i)
        stringify_entity(e)
    end
    return table.concat(out, '\n')
end

return stringify
