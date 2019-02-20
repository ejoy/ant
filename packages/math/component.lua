local ecs = ...
local world = ecs.world
local schema = ecs.schema

local math3d = require "math3d"
local ms = require "stack"

schema:typedef("vector", "real[4]")

local vector = ecs.component "vector"

function vector.init(s)
    local v = math3d.ref "vector"
    ms(v, s, "=")
    return v
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

schema:typedef("matrix", "real[16]")

local matrix = ecs.component "matrix"

function matrix.init(s)
    local v = math3d.ref "matrix"
    ms(v, s, "=")
    return v
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
