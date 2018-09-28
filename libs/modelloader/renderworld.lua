local ecs = ...
local world = ecs.world

local component_util = require "render.components.util"
local add_entity_sys = ecs.system "add_entities_system"
add_entity_sys.singleton "math_stack"
add_entity_sys.singleton "constant"
add_entity_sys.depend "constant_init_sys"
add_entity_sys.dependby "iup_message"

local fs_util = require "filesystem.util"
local lu = require "render.light.util"

function add_entity_sys:init()
	local ms = self.math_stack
	
	local leid = lu.create_directional_light_entity(world)
	local lentity = world[leid]
	local lightcomp = lentity.light.v
	lightcomp.color = {1,1,1,1}
	lightcomp.intensity = 2.0
	ms(lentity.rotation.v, {123.4, -34.22,-28.2}, "=")
	ms(lentity.position.v, {2, 5, 2}, "=")

	local am_eid = lu.create_ambient_light_entity(world)
	local am_entity = world[am_eid]
	local ambient_comp = am_entity.ambient_light.data
	ambient_comp.mode = "color" 
	ambient_comp.skycolor = {1,1,1,1}
	ambient_comp.midcolor  = {0.9,0.9,1,1}
	ambient_comp.groundcolor  = {0.60,0.74,0.68,1}

    local eid = world:new_entity(
        "position", "rotation", "scale",
        "can_render", "mesh", "material",
        "name"
    )
    local model = world[eid]
    ms(model.position.v, {0, 0, 0, 1}, "=")
    ms(model.rotation.v, {-90, -90, 0,}, "=")
    ms(model.scale.v, {0.2, 0.2, 0.2, 0}, "=")
    component_util.load_mesh(model, "PVPScene/campsite-door.mesh")
    component_util.load_material(model, {"PVPScene/scene-mat.material"})
end
