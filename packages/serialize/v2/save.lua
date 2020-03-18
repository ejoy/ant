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

local foreach_save_1

local function foreach_save_2(component, c)
    if c.attrib and c.attrib.tmp then
        if c.has_default or c.type == 'primtype' then
            if type(c.default) == 'function' then
                return c.default()
            end
            return c.default
        end
        return
    end
    if c.method and c.method.save then
        component = c.method.save(component)
    end
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
        return ret
    end
    if c.type then
        return foreach_save_1(component, c.type)
    end
    return foreach_save_1(component, c.name)
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
    local ret
    if not c.type then
        if c.multiple then
            ret = {}
            for i, com in world:each_component(component) do
                local r = {}
                ret[i] = r
                com.__type = name
                for _, v in ipairs(c) do
                    if com[v.name] == nil and v.attrib and v.attrib.opt then
                        goto continue
                    end
                    r[v.name] = foreach_save_2(com[v.name], typeinfo[v.type])
                    ::continue::
                end
            end
        else
            ret = {}
            component.__type = name
            for _, v in ipairs(c) do
                if component[v.name] == nil and v.attrib and v.attrib.opt then
                    goto continue
                end
                ret[v.name] = foreach_save_2(component[v.name], typeinfo[v.type])
                ::continue::
            end
        end
    else
        ret = foreach_save_2(component, c)
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
    return t
end

return {
    entity = save_entity,
}
