local ecs = ...
local world = ecs.world

ecs.import 'ant.basic_components'
ecs.import "ant.inputmgr"
ecs.import "ant.render"
ecs.import "ant.scene"
ecs.import "ant.serialize"
ecs.import "ant.event"
ecs.import "ant.math.adapter"

local math3d = import_package "ant.math"
local ms = math3d.stack
local mu = math3d.util
local model_review_system = ecs.system "model_review_system"

local renderpkg = import_package "ant.render"
local renderutil = renderpkg.util

model_review_system.singleton "constant"

model_review_system.depend "primitive_filter_system"
model_review_system.depend "render_system"
model_review_system.depend "viewport_detect_system"
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
	cu.create_grid_entity(world, "grid")
	world:create_entity {
		transform = mu.scale_mat(0.2),
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
		main_view = true,
	}

	local singlecolor_material = fs.path "//ant.resources/depiction/materials/singlecolor.material"
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

	local function create_submesh_item(material_refs)
		return {material_refs=material_refs, visible=true}
	end

	local meshes = {
		{
			path = fs.path "//ant.resources/depiction/meshes/build_boat_01.mesh",
			transform = mu.srt({1, 1, 1, 0}, nil, {15, 0, 0, 1}),
			material = create_material_item(singlecolor_material, {1, 0, 0, 0}),
		},
		{
			path = fs.path "//ant.resources/depiction/meshes/build_small_house_tall_roof_01.mesh",
			transform = mu.srt({1, 1, 1, 0}, nil, {-15, 0, 0, 1}),
			material = create_material_item(singlecolor_material, {0, 1, 0, 0}),
		},
		{
			path = fs.path "//ant.resources/depiction/meshes/build_big_storage_01.mesh",
			transform = mu.srt({1, 1, 1, 0}, mu.to_radian {0, 23.248, 0, 0}, {-35.40032, 2.527851, 35.10002, 1}),
			material = create_material_item(singlecolor_material, {0, 0, 1, 0}),
		},
		
	}

	for _, m in ipairs(meshes)do
		world:create_entity {
			transform = m.transform,
			can_render = true,
			mesh = {
				ref_path = m.path,
			},
			material = {
				content = {
					m.material,
				}
			},
			main_view = true,
		}
	end

	world:create_entity {
		transform = mu.srt({0.1, 0.1, 0.1}, nil,  {0, 0, 10}),
		can_render = true,
		mesh = {
			ref_path = fs.path "//ant.resources/depiction/meshes/test_glb.mesh",
			submesh_refs = {
				["build_big_storage_01_fence_02"] 		= create_submesh_item {1}, 
				["build_big_storage_01_pillars_01"] 	= create_submesh_item {2, 3},
				["build_big_storage_01_straw_roof_002"] = create_submesh_item {4, 5, 6, 7},
				["build_big_storage_01_walls_down"] 	= create_submesh_item {2},
				["build_big_storage_01_walls_up"] 		= create_submesh_item {2},
			},
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

	-- world:create_entity {
	-- 	transform = mu.srt({100,100,100}, {0, 134.039, 0.625}, {0, 0, 0,}),--{-73.84, 2.253, 33.53}),
	-- 	can_render = true,
	-- 	mesh = {
	-- 		ref_path = fs.path "//ant.resources/depiction/meshes/test_glb.mesh",
	-- 		-- submesh_refs = {
	-- 		-- 	material_refs = {

	-- 		-- 	},
	-- 		-- }
	-- 		-- material_refs = {
	-- 		-- 	["build_big_storage_01_fence_02"] = create_submesh_item {1}, 
	-- 		-- 	["build_big_storage_01_pillars_01"] = create_submesh_item {2, 3},
	-- 		-- 	["build_big_storage_01_straw_roof_002"] = create_submesh_item {4, 5, 6, 7},
	-- 		-- 	["build_big_storage_01_walls_down"] = create_submesh_item {2},
	-- 		-- 	["build_big_storage_01_walls_up"] = create_submesh_item {2},
	-- 		-- }
	-- 	},
	-- 	material = {
	-- 		content = {
	-- 			create_material_item(singlecolor_material, {1, 0, 0, 0}),
	-- 		}
	-- 	},
	-- 	main_view = true,
	-- }

	-- local mesh = model.mesh.assetinfo.handle.bounding
	--local bound = ms(mesh.aabb.max, mesh.aabb.min, "-T")
	--local scale = 10 / math.max(bound[1], math.max(bound[2], bound[3]))
	-- local trans = model.transform
	--ms(trans.s, {scale, scale, scale, 0}, "=")
	--ms(trans.t, {0, 0, 0, 1}, {0,mesh.aabb.min[2],0,1}, {scale}, "*-=")
end