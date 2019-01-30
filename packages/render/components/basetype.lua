local ecs = ...
local world = ecs.world
local schema = world.schema

local function gen_basetype(name, default)
    schema:primtype(name, default)
    local m = ecs.component(name)
    function m.save(v) return v end
    function m.load(v) return v end
end

gen_basetype("int", 0)
gen_basetype("real", 0.0)
gen_basetype("string", "")
gen_basetype("boolean", false)
