local datalist = require 'datalist'

local pool
local out
local stack
local typeinfo

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

local function stringify_array_value(c, array, v, load)
    if not load and c.method and c.method.load then
        load = c.name
    end
    if c.type ~= 'primtype' then
        return stringify_array_value(typeinfo[c.type], array, v, load)
    end
    local n = array == 0 and #v or array
    local s = {}
    for i = 1, n do
        s[i] = stringify_basetype(c.name, v[i])
    end
    if load then
        if load == 'vector' or load == 'matrix' then
            return '['..table.concat(s, ',')..']'
        end
        return '['..load..',{'..table.concat(s, ',')..'}]'
    end
    return '{'..table.concat(s, ',')..'}'
end

local function stringify_map_value(c, v, load)
    if not load and c.method and c.method.load then
        load = c.name
    end
    if c.type ~= 'primtype' then
        return stringify_map_value(typeinfo[c.type], v, load)
    end
    local s = {}
    for i = 1, #v do
        s[#s+1] = v[i][1]..':'..stringify_basetype(c.name, v[i][2])
    end
    if load then
        return '['..load..',{'..table.concat(s, ',')..'}]'
    end
    return '{'..table.concat(s, ',')..'}'
end

local function stringify_value(c, v, load)
    assert(c.type)
    if c.array then
        return stringify_array_value(c, c.array, v, load)
    end
    if c.map then
        return stringify_map_value(c, v, load)
    end
    if c.type == 'primtype' then
        if load then
            return '['..load..','..stringify_basetype(c.name, v)..']'
        end
        return stringify_basetype(c.name, v)
    end
    if not load and c.method and c.method.load then
        load = c.name
    end
    return stringify_value(typeinfo[c.type], v, load)
end

local function stringify_component_value(name, v)
    assert(typeinfo[name], "unknown type:" .. name)
    local c = typeinfo[name]
    if not c.ref then
        return stringify_value(c, v)
    end
    if not pool[v] then
        pool[v] = v.__id
        stack[#stack+1] = {c, v}
    end
    return ('*%s'):format(pool[v])
end

local stringify_component_ref

local function stringify_component_children(c, v)
    if not c.ref then
        return stringify_value(c, v)
    end
    if c.array then
        local n = c.array == 0 and #v or c.array
        for i = 1, n do
            out[#out+1] = ('  --- %s'):format(stringify_component_value(typeinfo[c.type].name, v[i]))
        end
        return
    end
    if c.map then
        for i = 1, #v do
            out[#out+1] = ('  %s:%s'):format(v[i][1], stringify_component_value(typeinfo[c.type].name, v[i][2]))
        end
        return
    end
    return stringify_component_value(c.type, v)
end

function stringify_component_ref(c, v, lv)
    assert(not c.type)
    for _, cv in ipairs(c) do
        if v[cv.name] == nil and cv.attrib and cv.attrib.opt then
            goto continue
        end
        if cv.ref and (cv.array or cv.map) then
            out[#out+1] = ('  '):rep(lv) .. ('%s:'):format(cv.name)
            stringify_component_children(cv, v[cv.name])
        else
            out[#out+1] = ('  '):rep(lv) .. ('%s:%s'):format(cv.name, stringify_component_children(cv, v[cv.name]))
        end
        ::continue::
    end
end

local function stringify_entity(e)
    out[#out+1] = ('--- &%s'):format(e.__id)
    for _, c in ipairs(e) do
        local k, v = c[1], c[2]
        out[#out+1] = ('%s:%s'):format(k, stringify_component_value(k, v))
    end

    while #stack ~= 0 do
        local c, v = stack[1][1], stack[1][2]
        table.remove(stack, 1)

        out[#out+1] = ('--- &%s'):format(pool[v])
        stringify_component_ref(c, v, 0)
    end
end

local function stringify(w, t)
    pool = {}
    stack = {}
    typeinfo = w.schema.map
    cid = 0
    
    local entity, component = t[1], t[2]
    local out1, out2, out3 = {}, {}, {}

    out = out1
    out[#out+1] = '---'
    for _, e in ipairs(entity) do
        out[#out+1] = ('  --- *%s'):format(e.__id)
    end

    out = out3
    for _, e in ipairs(entity) do
        stringify_entity(e)
    end

    out = out2
    out[#out+1] = '---'
    for _, cs in ipairs(component) do
        out[#out+1] = '  ---'
        out[#out+1] = ('    --- %s'):format(cs[1])
        local l = {}
        for _, v in ipairs(cs[2]) do
            l[#l+1] = pool[v]
        end
        table.sort(l)
        for _, v in ipairs(l) do
            out[#out+1] = ('    --- *%s'):format(v)
        end
    end

    table.move(out2, 1, #out2, #out1+1, out1)
    table.move(out3, 1, #out3, #out1+1, out1)
    out1[#out1+1] = ''
    return table.concat(out1, '\n')
end

return stringify
