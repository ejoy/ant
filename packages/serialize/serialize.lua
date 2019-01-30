local create_method = require "method"
local datalist = require 'datalist'
local method

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

local function save_entity(w, msave, eid)
    local e = assert(w[eid])
    local t = {}
    for name, cv in sortpairs(e) do
        t[name] = msave[name](cv)
    end
    return t
end

local function save(w)
    if not method then
        method = create_method(w)
    end
    method.reset()
    local t = {}
    for _, eid in w:each "serialize" do
        t[#t+1] = save_entity(w, method.save, eid)
    end
    method.reset()
    return t
end

local function load_entity(w, mload, tree, args)
    local eid = w:new_entity()
    local e = w[eid]
    args.eid = eid
    for name, cv in pairs(tree) do
        w:add_component(eid, name)
        args.comp = name
        e[name] = mload[name](cv, args)
    end
    return eid
end

local function load(w, t)
    if not method then
        method = create_method(w)
    end
    local args = { world = w }
    for _, tree in ipairs(t) do
        load_entity(w, method.load, tree, args)
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
