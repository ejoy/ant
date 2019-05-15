local datalist = require 'datalist'

local postPool = {}
local doPost
local component
local entitys

local function sortcomponent(w, t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    local ti = w._components
    table.sort(sort, function (a, b) return ti[a].sortid < ti[b].sortid end)
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

local function init_entitys(w)
    local res = {}
    for _, eid in w:each "serialize" do
        res[w[eid].serialize] = eid
    end
    return res
end

local function getPost(w)
    if not postPool[w] then
        local t = {}
        for k, v in pairs(w._components) do
            if v.method and v.method.init then
                t[k] = v.method.init
            end
        end
        postPool[w] = t
    end
    return postPool[w]
end

local function finish_entity(w, e)
    for name in sortcomponent(w, e) do
        w:finish_component(e, name)
    end
end

local function _load_entity(w, tree)
    local eid
    if entitys then
        eid = entitys[tree.serialize]
        if not eid then
            eid = w:register_entity()
            entitys[tree.serialize] = eid
        end
    else
        eid = w:register_entity()
    end
    w[eid] = tree
    for name in sortpairs(tree) do
        w:register_component(eid, name)
    end
    return tree, eid
end

local function load_start(w, s)  
    local post = getPost(w)
    function doPost(type, value)
        if type == 'entity' then
            if not entitys then
                entitys = init_entitys(w)
            end
            local eid = entitys[value]
            if not eid then
                eid = w:register_entity()
                w[eid] = {}
                entitys[value] = eid
            end
            return eid
        end
        assert(post[type])
        return post[type](value)
    end

    local res, ids = datalist.parse(s, function(t)
        if type(t[1]) == 'number' then
            if #t == 4 or #t == 3 then
                return doPost('vector', t)
            elseif #t == 16 then
                return doPost('matrix', t)
            else
                error('invalid data.')
            end
        end
        return doPost(t[1], t[2])
    end)
    local slove = false
    for _, name in ipairs(res[1]) do
        slove = w:import(name) or slove
    end
    if slove then
        w:slove_comonpent()
    end
    w.__deserialize = ids
    component = res[3]
    return res[2]
end

local function load_end()
    for _, cs in ipairs(component) do
        local type = cs[1]
        for i = 2, #cs do
            doPost(type, cs[i])
        end
    end
end

local function load_world(w, s)
    local entity = load_start(w, s)
    local l = {}
    for _, tree in ipairs(entity) do
        l[#l+1], eid = _load_entity(w, tree)
    end
    load_end()
    for _, e in ipairs(l) do
        finish_entity(w, e)
    end
end

local function load_entity(w, s)
    local entity = load_start(w, s)
    local e, eid = _load_entity(w, entity)
    load_end()
    finish_entity(w, e)
    return eid
end

return {
    world = load_world,
    entity = load_entity,
}
