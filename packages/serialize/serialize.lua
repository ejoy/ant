local datalist = require 'datalist'

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

local function save_entity(w, eid, args)
    local e = assert(w[eid])
    local t = {}
    args.eid = eid
    for name, cv in sortpairs(e) do
        args.comp = name
        t[#t+1] = name
        t[#t+1] = w._component_type[name].save(cv, args)
    end
    return t
end

local function save(w)
    local args = { world = w }
    local t = {}
    for _, eid in w:each "serialize" do
        t[#t+1] = save_entity(w, eid, args)
    end
    return t
end

local function load_entity(w, tree, args)
    local eid = w:new_entity()
    local e = w[eid]
    args.eid = eid
    for i = 1, #tree, 2 do
        local name, cv = tree[i], tree[i+1]
        w:add_component(eid, name)
        args.comp = name
        e[name] = w._component_type[name].load(cv, args)
    end
    return eid
end

local function load(world, t)
    local args = { world = w }
    for _, tree in ipairs(t) do
        load_entity(world, tree, args)
    end
end

local function parse(s)
    return datalist.parse(s)
end

return {
    save = save,
    load = load,
    stringify = require 'stringify',
    parse = parse,
}
