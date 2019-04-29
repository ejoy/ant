local save = require "save"

local m = {}

local typeinfo

local function split(s)
    local r = {}
    s:gsub('[^/]*', function (w) r[#r+1] = w end)
    return r
end

local function path2component(o, name, sp)
    if #sp == 0 then
        return o, name
    end
    local k = sp[1]
    table.remove(sp, 1)
    if k == '' then
        return path2component(o, name, sp)
    end
    local ti = typeinfo[name]
    if ti.array then
        k = tonumber(k)
        return path2component(o[k], ti.type, sp)
    end
    if not ti.type then
        for _, v in ipairs(ti) do
            if v.name == k then
                return path2component(o[k], v.type, sp)
            end
        end
    end
    return path2component(o[k], ti.type, sp)
end

local function path2entity(o, sp)
    if #sp == 0 then
        return o, 'entity'
    end
    local k = sp[1]
    table.remove(sp, 1)
    return path2component(o[k], k, sp)
end

local function getobject(w, id, path)
    typeinfo = w._components
    local sp = split(path)
    if id then
        local ids = w.__deserialize
        if not ids or not ids[id] then
            error('invalid id')
        end
        local t = ids[id]
        return path2component(t, t.__type, sp)
    end
    local eid = tonumber(sp[1])
    if not eid or not w[eid] then
        error('invalid eid')
    end
    table.remove(sp, 1)
    return path2entity(w[eid], sp)
end

function m.query(w, id, path)
    local component, name = getobject(w, id, path)
    return save.component(w, component, name)
end

function m.set(w, id, path, key, value)
    local component, name = getobject(w, id, path)
    local c = typeinfo[name]
    assert(not c.type)
    for _, v in ipairs(c) do
        if v.name == key then
            component[v.name] = w:create_component(v.type, value)
            return
        end
    end
    error('invalid key')
end

return m
