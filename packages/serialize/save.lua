local method = require "method"
local crypt = require "crypt"

local pool
local typeinfo
local ids

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
        for k, v in sortpairs(component) do
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
        ret = {
            __id = ids[component] and ids[component] or crypt.uuid64()
        }
        for _, v in ipairs(c) do
            --TODO: 现在所有字段都是可选字段
            if component[v.name] ~= nil then
                ret[v.name] = foreach_save_2(component[v.name], v)
            end
        end
        if c.method and c.method.save then
            c.method.save(ret)
        end
        if c.method and c.method.load then
            load[c.name] = load[c.name] or {}
            table.insert(load[c.name], ret)
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
    local e = assert(w[eid])
    local t = {
        __id = ids[e] and ids[e] or crypt.uuid64()
    }
    for name, cv in sortpairs(e) do
        t[#t+1] = { name, foreach_save_1(cv, name) }
    end
    return t
end

local function update_deserialize(w)
    ids = {}
    if not w.__deserialize then
        return
    end
    for id, t in pairs(w.__deserialize) do
        ids[t] = tostring(id):sub(11)
    end
end

local function save(w)
    method.init(w)
    pool = {}
    load = {}
    typeinfo = w.schema.map
    update_deserialize(w)
    local entity = {}
    for _, eid in w:each "serialize" do
        entity[#entity+1] = save_entity(w, eid, ids)
    end

    local component = {}
    for name, v in pairs(load) do
        component[#component+1] = { name, v }
    end

    table.sort(entity, function(a, b) return a.__id < b.__id end)
    table.sort(component, function (a,b) return a[1] < b[1] end)
    return { entity, component }
end

return save
