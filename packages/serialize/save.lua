local world
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
    assert(typeinfo[name], "unknown type:" .. name)
    local c = typeinfo[name]
    if c.methodfunc and c.methodfunc.save then
        component = c.methodfunc.save(component)
    end
    local ret
    if not c.type then
        ret = {}
        save_component(ret, c, component)
    else
        ret = foreach_save_1(component, c.type)
    end
    if c.methodfunc and c.methodfunc.init then
        ret = setmetatable({ret}, {__component = name})
    end
    return ret
end

local function save_entity(w, eid)
    world = w
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
