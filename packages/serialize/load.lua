local datalist = require 'datalist'

local postPool = {}
local doPost
local component
local entitys

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
        for k, v in pairs(w._schema.map) do
            if v.method and v.method.init then
                t[k] = v.method.init
            end
        end
        postPool[w] = t
    end
    return postPool[w]
end

local function _load_entity(w, tree)
    local eid = entitys[tree.serialize]
    if not eid then
        eid = w:register_entity()
        if entitys then
            entitys[tree.serialize] = eid
        end
    end
    w[eid] = tree
    for name in pairs(tree) do
        w:register_component(eid, name)
    end
    return eid
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
    w.__deserialize = ids
    component = res[2]
    return res[1]
end

local function load_end(w)
    for _, cs in ipairs(component) do
        local type = cs[1]
        for i = 2, #cs do
            doPost(type, cs[i])
        end
    end
end

local function load_world(w, s)
    local entity = load_start(w, s)
    for _, tree in ipairs(entity) do
        _load_entity(w, tree)
    end
    load_end()
end

local function load_entity(w, s)
    local entity = load_start(w, s)
    _load_entity(w, entity)
    load_end()
end

return {
    world = load_world,
    entity = load_entity,
}
