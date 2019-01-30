local method = require "method"
local datalist = require 'datalist'

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
    method.init(w)
    local args = { world = w }
    for _, tree in ipairs(t) do
        load_entity(w, method.load, tree, args)
    end
end

local function parse(s)
    return datalist.parse(s)
end

return {
    save = require "save",
    load = load,
    stringify = require 'stringify',
    parse = parse,
}
