local ecs = ...
local world = ecs.world

ecs.import 'ant.basic_components'
ecs.import "ant.inputmgr"
ecs.import "ant.render"
ecs.import "ant.scene"
ecs.import "ant.serialize"
ecs.import "ant.event"

local math3d = import_package "ant.math"
local ms = math3d.stack
local model_review_system = ecs.system "model_review_system"

model_review_system.singleton "constant"
model_review_system.depend "constant_init_sys"
model_review_system.dependby "message_system"
--model_review_system.depend "shadow_primitive_filter_system"
model_review_system.depend "transparency_filter_system"
model_review_system.depend "entity_rendering"
model_review_system.depend "debug_system"

local lu = import_package "ant.render" .light
local cu = import_package "ant.render" .components
local fs = require "filesystem"

local function to_radian(angle)
	return (math.pi / 180) * angle
end

local function create_light()
	local leid = lu.create_directional_light_entity(world, "direction light", {1,1,1,1}, 2)
	local lentity = world[leid]

	ms(lentity.rotation, {to_radian(123.4), to_radian(-34.22), to_radian(-28.2)}, "=")

	lu.create_ambient_light_entity(world, "ambient light", {1, 1, 1, 1}, {0.9, 0.9, 1, 1}, {0.60,0.74,0.68,1})
end

function model_review_system:init()
	create_light()
	cu.create_grid_entity(world, "grid")
	world:create_entity {
		transform = {			
			s = {0.2, 0.2, 0.2, 0},
			r = {-math.pi * 0.5, -math.pi * 0.5, 0, 0},
			t = {0, 0, 0, 1},
		},
		can_render = true,
		mesh = {
			ref_path = fs.path "//ant.resources/PVPScene/campsite-door.mesh"
		},
		material = {
			content = {
				{
					ref_path = fs.path "//ant.resources/PVPScene/scene-mat.material",
				}
			}
		},
		main_viewtag = true,		
	}

	world:create_entity {
		transform = {
			s = {0.01, 0.01, 0.01},
			r = {0, 0, 0, 0},
			t = {2, 2, 2},
		},
		can_render = true,
		mesh = {
			ref_path = fs.path "//ant.resources/cube.mesh",
		},
		material = {
			content = {
				{
					ref_path = fs.path "//ant.resources/bunny.material"
				}
			}
		},
		main_viewtag = true,
	}

	-- local mesh = model.mesh.assetinfo.handle.bounding
	--local bound = ms(mesh.aabb.max, mesh.aabb.min, "-T")
	--local scale = 10 / math.max(bound[1], math.max(bound[2], bound[3]))
	-- local trans = model.transform
	--ms(trans.s, {scale, scale, scale, 0}, "=")
	--ms(trans.t, {0, 0, 0, 1}, {0,mesh.aabb.min[2],0,1}, {scale}, "*-=")
end