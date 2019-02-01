local datalist = require 'datalist'

local postPool = {}

local function getPost(w)
    if not postPool[w] then
        local t = {}
        for k, v in pairs(w.schema.map) do
            if v.method and v.method.load then
                t[k] = v.method.load
            end
        end
        postPool[w] = t
    end
    return postPool[w]
end

local function load_entity(w, tree)
    local eid = w:register_entity()
    w[eid] = tree
    for name in pairs(tree) do
        w:register_component(eid, name)
    end
    return eid
end

local function load_world(w, s)
    local post = getPost(w)
    local function doPost(type, value)
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

    local entity, component = res[1], res[2]
    for _, tree in ipairs(entity) do
        load_entity(w, tree)
    end
    for _, cs in ipairs(component) do
        local type = cs[1]
        for i = 2, #cs do
            doPost(type, cs[i])
        end
    end
end

return {
    world = load_world,
    entity = load_entity,
}
