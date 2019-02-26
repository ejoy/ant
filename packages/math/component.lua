local ecs = ...

local math3d = require "math3d"
local ms = require "stack"

local vector = ecs.component_alias("vector", "real[4]")

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

local matrix = ecs.component_alias("matrix", "real[16]")

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
