local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"
ecs.import "ant.render"
ecs.import "ant.scene"
ecs.import "ant.serialize"
ecs.import "ant.event"
ecs.import "ant.math.adapter"
ecs.import "ant.sky"
ecs.import "ant.asset"
ecs.import "ant.imguibase"
ecs.import "ant.camera_controller"

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local mu = mathpkg.util

local imgui = require "imgui"

local model_review_system = ecs.system "model_review_system"

local renderpkg = import_package "ant.render"

local skypkg = import_package "ant.sky"
local skyutil = skypkg.util

model_review_system.singleton "constant"

model_review_system.depend "primitive_filter_system"
model_review_system.depend "render_system"
model_review_system.depend "viewport_detect_system"
model_review_system.depend "procedural_sky_system"
model_review_system.depend "cull_system"
model_review_system.depend "luagc_system"
model_review_system.depend "shadow_maker"
--model_review_system.depend "render_mesh_bounding"
model_review_system.dependby "camera_controller_2"
model_review_system.depend "imgui_runtime_system"
model_review_system.depend "steering_system"

local lu = renderpkg.light
local cu = renderpkg.components
local fs = require "filesystem"

local serialize = import_package 'ant.serialize'

local function create_light()
	lu.create_directional_light_entity(world, "direction light", 
		{1,1,1,1}, 2, mu.to_radian{60, 50, 0})
	lu.create_ambient_light_entity(world, "ambient light", 'color', {1, 1, 1, 1}, {0.9, 0.9, 1, 1}, {0.60,0.74,0.68,1})
end

local singlecolor_material = fs.path "/pkg/ant.resources/depiction/materials/singlecolor.material"
local function create_material_item(filepath, color)
	return {
		ref_path = filepath,
		properties = {
			uniforms = {
				u_color = {type = "color", name = "Color", value = color},
			}
		},
		asyn_load = true,
	}
end

function model_review_system:init()
	create_light()
	skyutil.create_procedural_sky(world, {follow_by_directional_light=false})

	-- world:create_entity {
	-- 	transform = mu.srt(),
	-- 	rendermesh = {},
	-- 	material = {{ref_path = fs.path "/pkg/ant.modelviewer/res/test.material"}},
	-- 	name = "test",
	-- 	can_render = true,
	-- 	main_view = true,
	-- }

	-- world:create_entity {
	-- 	name = "terrain far",
	-- 	transform = mu.srt({-0.1, 0.1, 0.1},{0.000,0.000,0.000},{0, -5, 0, 1}),
	-- 	rendermesh = {},
	-- 	mesh = {
	-- 		ref_path = fs.path "/pkg/ant.resources/depiction/meshes/test.mesh",
	-- 		submesh_refs = {
	-- 			terrain_far_01 = cu.create_submesh_item {0},
	-- 			terrain_near_01 = cu.create_submesh_item {1, 2},
	-- 		},
	-- 		asyn_load = true,
	-- 	},
	-- 	material = {
	-- 		create_material_item(singlecolor_material, {1, 0, 0, 0}),
	-- 		create_material_item(singlecolor_material, {1, 1, 0, 0}),
	-- 		create_material_item(singlecolor_material, {1, 0, 1, 0}),
	-- 	},
	-- 	asyn_load = "",
	-- 	main_view = true,
	-- 	can_render = true,
	-- }

	--cu.create_grid_entity(world, "grid")
	cu.create_plane_entity(world, 
		{50, 1, 50, 0}, nil, 
		fs.path "/pkg/ant.resources/depiction/materials/test/mesh_shadow.material", 
		{0.8, 0.8, 0.8, 1},
		"test shadow plane")

	--cu.create_axis_entity(world, mu.translate_mat{0, 0, 1})

	local origineid = world:create_entity {
		transform 	= mu.scale_mat(0.2),
		rendermesh 	= {},
		mesh 		= {ref_path = fs.path "/pkg/ant.resources/depiction/PVPScene/campsite-door.mesh", asyn_load=true},
		material 	= {{ref_path = fs.path "/pkg/ant.resources/depiction/PVPScene/scene-mat.material", asyn_load=true}},
		can_render 	= true,
		main_view 	= true,
		asyn_load	= "",
		can_cast	= true,
		name 		= "door",
		serialize   = serialize.create(),
	}

	world:create_entity {
		transform 	= mu.srt({0.2, 0.2, 0.2}, nil, {5, 0, 0}),
		rendermesh 	= {},
		mesh 		= {ref_path = fs.path "/pkg/ant.resources/depiction/PVPScene/woodother-34.mesh", asyn_load=true},
		material 	= {{ref_path = fs.path "/pkg/ant.resources/depiction/PVPScene/scene-mat.material", asyn_load=true}},
		can_render 	= true,
		main_view 	= true,
		asyn_load	= "",
		can_cast	= true,
		name 		= "door",
		serialize   = serialize.create(),
	}

	-- local originentity = world[origineid]
	-- local s, r, t = ms(originentity.transform.t, originentity.transform.r, originentity.transform.s, "TTT")
	-- world:create_entity {
	-- 	transform 	= mu.srt(s, r, t),
	-- 	rendermesh 	= {},
	-- 	material 	= {{ref_path = fs.path "/pkg/ant.resources/depiction/materials/outline/scale.material",}},
	-- 	can_render 	= true,
	-- 	main_view 	= true,
	-- 	name 		= "door_outline",
	-- }

	world:create_entity {
		transform = mu.srt({0.1, 0.1, 0.1}, nil,  {0, 0, 10}),
		can_render = true,
		rendermesh = {
			submesh_refs = {
				["build_big_storage_01_fence_02"] 		= cu.create_submesh_item {1}, 
				["build_big_storage_01_pillars_01"] 	= cu.create_submesh_item {2, 3},
				["build_big_storage_01_straw_roof_002"] = cu.create_submesh_item {4, 5, 6, 7},
				["build_big_storage_01_walls_down"] 	= cu.create_submesh_item {2},
				["build_big_storage_01_walls_up"] 		= cu.create_submesh_item {2},
			},
		},
		mesh = {
			ref_path = fs.path "/pkg/ant.resources/depiction/meshes/test_glb.mesh",
			asyn_load = true,
		},
		material = {
			create_material_item(singlecolor_material, {1, 0, 0, 0}),
			create_material_item(singlecolor_material, {0, 1, 0, 0}),
			create_material_item(singlecolor_material, {0, 0, 1, 0}),
			create_material_item(singlecolor_material, {1, 1, 0, 0}),
			create_material_item(singlecolor_material, {1, 0, 1, 0}),
			create_material_item(singlecolor_material, {0, 1, 1, 0}),
			create_material_item(singlecolor_material, {1, 1, 1, 0}),
		},
		main_view = true,
		can_cast = true,
		asyn_load = "",
		name = "test_glb",
		serialize   = serialize.create(),
	}
	
    --local function save_file(file, data)
    --    assert(assert(io.open(file, 'w')):write(data)):close()
    --end
    ---- test serialize world
    --local s = serialize.save_world(world)
    --save_file('serialize_world.txt', s)
    --for _, eid in world:each 'serialize' do
    --    world:remove_entity(eid)
    --end
	--serialize.load_world(world, s)

    --local eid = world:first_entity_id 'serialize'
    --local s = serialize.save_entity(world, eid)
    --save_file('serialize_entity.txt', s)
    --world:remove_entity(eid)
	--serialize.load_entity(world, s)
	

	-- local function find_entity_by_name(name)
	-- 	for _, eid in world:each "can_render" do
	-- 		local e = world[eid]
	-- 		if e.name == name then
	-- 			return eid
	-- 		end
	-- 	end
	-- end

	-- local dooreid = find_entity_by_name("door")
	-- local door_outlineeid = find_entity_by_name("door_outline")
	-- world[dooreid].rendermesh = world[door_outlineeid].rendermesh
end

local function memory_info()
	local function bytestr(n)
		if n < 1024 then
			return ("%dB"):format(n)
		end
		n = n / 1024.0
		if n < 1024 then
			return ("%.1fKB"):format(n)
		end
		n = n / 1024.0
		return ("%.1fMB"):format(n)
	end

	local s = {}
	local platform = require "platform"
	local bgfx = require "bgfx"
	s[#s+1] = ""
	s[#s+1] = ("sys   memory:%s"):format(bytestr(platform.info "memory"))
	s[#s+1] = ("lua   memory:%s"):format(bytestr(collectgarbage "count" * 1024.0))
	s[#s+1] = ("bgfx  memory:%s"):format(bytestr(bgfx.get_memory()))
	s[#s+1] = ("math  memory:%s"):format(bytestr(ms:stacksize()))
	s[#s+1] = ("imgui memory:%s"):format(bytestr(imgui.get_memory()))
	
	s[#s+1] = "-------------------"

	local data = bgfx.get_stats "m"
	s[#s+1] = ("rt   memory:%s"):format(bytestr(data.rtMemoryUsed))
	s[#s+1] = ("tex  memory:%s"):format(bytestr(data.textureMemoryUsed))
	s[#s+1] = ("vb   memory:%s"):format(bytestr(data.transientVbUsed))
	s[#s+1] = ("ib   memory:%s"):format(bytestr(data.transientIbUsed))
	s[#s+1] = ""

	local leaks = ms:leaks()
	if leaks and #leaks >= 0 then
		s[#s+1] = "-------------------"
		s[#s+1] = ("math3d leaks: %d"):format(#leaks)
	end
	
	return table.concat(s, "\t\n\t")
end

function model_review_system:on_gui()
	local windows = imgui.windows
	local widget = imgui.widget

	windows.Begin("Test")
	widget.Text(memory_info())
	windows.End()
end
