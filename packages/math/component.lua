local ecs = ...
local world = ecs.world
local schema = world.schema

local math3d = require "math3d"
local ms = require "stack"

schema:userdata "vector"

local vector = ecs.component_v2 "vector"

function vector.init()
    return math3d.ref "vector"
end

function vector.delete(m)
    m()
end

function vector.save(v)
    assert(type(v) == "userdata")	
    local t = ms(v, "T")
    assert(type(t) == "table" and t.type ~= nil)
    assert(t.type == "v4", "vector load function need vector type")
    t.type = nil
    return t
end

function vector.load(s)
    local v = math3d.ref "vector"
    s.type = "v4"
    ms(v, s, "=")
    return v
end

schema:userdata "matrix"

local matrix = ecs.component_v2 "matrix"

function matrix.init()
    return math3d.ref "vector"
end

function matrix.delete(m)
    m()
end

function matrix.save(v)
    assert(type(v) == "userdata")	
    local t = ms(v, "T")
    assert(type(t) == "table" and t.type ~= nil)
    assert(t.type == "m4", "matrix load function need matrix type")
    t.type = nil
    return t
end

function matrix.load(s)
    local v = math3d.ref "matrix"
    s.type = "m4"
    ms(v, s, "=")
    return v
end
