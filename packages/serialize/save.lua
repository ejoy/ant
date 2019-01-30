local method = require "method"

local pool
local typeinfo

local foreach_save_1
local function foreach_save_3(component, c)
    if c.method and c.method.save then
        return c.method.save(component)
    end
    return foreach_save_1(component, c.type)
end

local function foreach_save_2(component, c)
    if c.method and c.method.save then
        return c.method.save(component)
    end
    if c.array then
        local n = c.array == 0 and #component or c.array
        local ret = {}
        for i = 1, n do
            ret[i] = foreach_save_3(component[i], c)
        end
        return ret
    end
    if c.map then
		local ret = {}
        for k, v in pairs(component) do
			ret[#ret+1] = {k , foreach_save_3(v, c)}
		end
        return ret
    end
    return foreach_save_1(component, c.type)
end

function foreach_save_1(component, name)
    if name == 'primtype' then
        return component
    end
    assert(typeinfo[name], "unknown type:" .. name)
    local c = typeinfo[name]
    if c.ref and pool[component] then
        return pool[component]
    end
    local ret 
    if not c.type then
        ret = {}
        for _, v in ipairs(c) do
            --TODO: 现在所有字段都是可选字段
            if component[v.name] ~= nil then
                ret[v.name] = foreach_save_2(component[v.name], v)
            end
        end
        if c.method and c.method.save then
            c.method.save(ret)
        end
    else
        ret = foreach_save_2(component, c)
    end
    if c.ref then
        pool[component] = ret
    end
    return ret
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

local function save_entity(w, eid)
    local e = assert(w[eid])
    local t = {}
    for name, cv in sortpairs(e) do
        t[#t+1] = { name, foreach_save_1(cv, name) }
    end
    return t
end

local function save(w)
    method.init(w)
    pool = {}
    load = {}
    typeinfo = w.schema.map
    local t = {}
    for _, eid in w:each "serialize" do
        t[#t+1] = save_entity(w, eid)
    end
    return t
end

return save
