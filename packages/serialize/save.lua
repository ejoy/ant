local world
local pool
local typeinfo

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

local MapMetatable <const> = {__name = 'serialize.map'}
local function markMap(t)
    if next(t) == nil then
        return setmetatable(t, MapMetatable)
    end
    return t
end

local foreach_save_1

local function foreach_save_2(component, c)
    if c.array then
        local n = c.array == 0 and #component or c.array
        local ret = {}
        for i = 1, n do
            ret[i] = foreach_save_1(component[i], c.type)
        end
        return ret
    end
    if c.map then
        local ret = {}
        for k, v in pairs(component) do
            if type(k) == "string" then
                ret[k] = foreach_save_1(v, c.type)
            end
        end
        markMap(ret)
        return ret
    end
    return foreach_save_1(component, c.type)
end

local function save_component(res, typeinfo, value)
    for _, v in ipairs(typeinfo) do
        if value[v.name] == nil and v.attrib and v.attrib.opt then
            goto continue
        end
        res[v.name] = foreach_save_2(value[v.name], v)
        ::continue::
    end
    markMap(res)
end

function foreach_save_1(component, name)
    if name == 'primtype' then
        return component
    end
    if name == 'entityid' then
        local entity = world[component]
        assert(entity, "unknown entityid: "..component)
        assert(entity.serialize, "entity("..component..") doesn't allow serialization.")
        return entity.serialize
    end
    assert(typeinfo[name], "unknown type:" .. name)
    local c = typeinfo[name]
    if c.ref and pool[component] then
        return pool[component]
    end
    if c.methodfunc and c.methodfunc.save then
        component = c.methodfunc.save(component)
    end
    local ret
    if not c.type then
        if c.multiple then
            ret = {}
            save_component(ret, c, component)
            for i, com in ipairs(component) do
                local r = {}
                ret[i] = r
                save_component(r, c, com)
            end
        else
            ret = {}
            save_component(ret, c, component)
        end
    else
        ret = foreach_save_1(component, c.type)
    end
    if c.ref then
        pool[component] = ret
    end
    return ret
end

local function save_entity(w, eid)
    world = w
    pool = {}
    typeinfo = w._class.component
    local e = assert(w[eid], 'invalid eid')
    local t = {}
    for name, cv in sortpairs(e) do
        t[name] = foreach_save_1(cv, name)
    end
    markMap(t)
    return t
end

return {
    entity = save_entity,
}
