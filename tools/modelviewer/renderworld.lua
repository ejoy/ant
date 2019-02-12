local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"
ecs.import "ant.render"
ecs.import "ant.scene"
ecs.import "ant.serialize"


local component_util = import_package "ant.render".components
local math = import_package "ant.math"
local ms = math.stack
local model_review_system = ecs.system "model_review_system"

model_review_system.singleton "constant"
model_review_system.depend "constant_init_sys"
model_review_system.dependby "message_system"

local lu = import_package "ant.render" .light
local cu = import_package "ant.render" .components
local fs = require "filesystem"

local function create_light()
	local leid = lu.create_directional_light_entity(world)
	local lentity = world[leid]
	local lightcomp = lentity.directional_light
	lightcomp.color = {1,1,1,1}
	lightcomp.intensity = 2.0
	ms(lentity.rotation, {123.4, -34.22,-28.2}, "=")

	local am_eid = lu.create_ambient_light_entity(world)
	local am_entity = world[am_eid]
	local ambient_comp = am_entity.ambient_light
	ambient_comp.mode = "color" 
	ambient_comp.skycolor = {1,1,1,1}
	ambient_comp.midcolor  = {0.9,0.9,1,1}
	ambient_comp.groundcolor  = {0.60,0.74,0.68,1}
end

function model_review_system:init()
	create_light()
	cu.create_grid_entity(world, "grid")

	local eid = world:new_entity(
		"position", "rotation", "scale",
		"can_render", "mesh", "material"
	)
	local model = world[eid]
	component_util.load_mesh(model.mesh, "ant.resources", fs.path "PVPScene/campsite-door.mesh")
	component_util.add_material(model.material, "ant.resources", fs.path "PVPScene/scene-mat.material")
	--component_util.load_mesh(model.mesh, "engine", "cube.mesh")
	--component_util.load_material(model.material,{"engine", "bunny.material"})

	local mesh = model.mesh.assetinfo.handle.bounding
	--local bound = ms(mesh.aabb.max, mesh.aabb.min, "-T")
	--local scale = 10 / math.max(bound[1], math.max(bound[2], bound[3]))
	--ms(model.scale, {scale, scale, scale, 0}, "=")
	--ms(model.position, {0, 0, 0, 1}, {0,mesh.aabb.min[2],0,1}, {scale}, "*-=")
	ms(model.scale, {0.2, 0.2, 0.2, 0}, "=")
	ms(model.position, {0, 0, 0, 1}, "=")
	ms(model.rotation, {-90, -90, 0,}, "=")
end
