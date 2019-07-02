local ecs = ...
local world = ecs.world

ecs.import 'ant.basic_components'
ecs.import "ant.inputmgr"
ecs.import "ant.render"
ecs.import "ant.scene"
ecs.import "ant.serialize"
ecs.import "ant.event"
ecs.import "ant.math.adapter"
ecs.import "ant.sky"

local math3d = import_package "ant.math"
local ms = math3d.stack
local mu = math3d.util
local model_review_system = ecs.system "model_review_system"

local renderpkg = import_package "ant.render"
local renderutil = renderpkg.util

local skypkg = import_package "ant.sky"
local skyutil = skypkg.util

model_review_system.singleton "constant"

model_review_system.depend "primitive_filter_system"
model_review_system.depend "render_system"
model_review_system.depend "viewport_detect_system"
model_review_system.depend "sky_system"
model_review_system.depend "cull_system"
model_review_system.dependby "camera_controller"

local lu = renderpkg.light
local cu = renderpkg.components
local viedidmgr = renderpkg.viewidmgr
local fs = require "filesystem"

local function create_light()
	local leid = lu.create_directional_light_entity(world, "direction light", {1,1,1,1}, 2)
	local lentity = world[leid]

	ms(lentity.rotation, {math.rad(123.4), math.rad(-34.22), math.rad(-28.2)}, "=")

	lu.create_ambient_light_entity(world, "ambient light", 'color', {1, 1, 1, 1}, {0.9, 0.9, 1, 1}, {0.60,0.74,0.68,1})
end

function model_review_system:init()
	local fbsize = world.args.fb_size	
	renderutil.create_main_queue(world, fbsize, ms({1, 1, -1}, "inT"), {5, 5, -5})
	renderutil.create_blit_queue(world, {x=0, y=0, w=fbsize.w, h=fbsize.h})
	create_light()
	skyutil.create_procedural_sky(world)
	
	cu.create_grid_entity(world, "grid")
	world:create_entity {
		transform = mu.scale_mat(0.2),
		can_render = true,
		mesh = {
			ref_path = fs.path "/pkg/ant.resources/PVPScene/campsite-door.mesh"
		},
		material = {
			content = {
				{
					ref_path = fs.path "/pkg/ant.resources/PVPScene/scene-mat.material",
				}
			}
		},
		main_view = true,
	}

	local singlecolor_material = fs.path "/pkg/ant.resources/depiction/materials/singlecolor.material"
	local function create_material_item(filepath, color)
		return {
			ref_path = filepath,
			properties = {
				uniforms = {
					u_color = {type = "color", name = "Color", value = color},
				}
			}
		}
	end

	world:create_entity {
		transform = mu.srt({0.1, 0.1, 0.1}, nil,  {0, 0, 10}),
		can_render = true,
		mesh = {
			ref_path = fs.path "/pkg/ant.resources/depiction/meshes/test_glb.mesh",
			-- submesh_refs = {
			-- 	["build_big_storage_01_fence_02"] 		= cu.create_submesh_item {1}, 
			-- 	["build_big_storage_01_pillars_01"] 	= cu.create_submesh_item {2, 3},
			-- 	["build_big_storage_01_straw_roof_002"] = cu.create_submesh_item {4, 5, 6, 7},
			-- 	["build_big_storage_01_walls_down"] 	= cu.create_submesh_item {2},
			-- 	["build_big_storage_01_walls_up"] 		= cu.create_submesh_item {2},
			-- },
		},
		material = {
			content = {
				create_material_item(singlecolor_material, {1, 0, 0, 0}),
				create_material_item(singlecolor_material, {0, 1, 0, 0}),
				create_material_item(singlecolor_material, {0, 0, 1, 0}),
				create_material_item(singlecolor_material, {1, 1, 0, 0}),
				create_material_item(singlecolor_material, {1, 0, 1, 0}),
				create_material_item(singlecolor_material, {0, 1, 1, 0}),
				create_material_item(singlecolor_material, {1, 1, 1, 0}),
			}
		},
		main_view = true,
	}
end