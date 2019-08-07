local ecs = ...
local world = ecs.world

local util 		= require "util"
local fs 		= require "filesystem"

ecs.import 'ant.basic_components'
ecs.import "ant.render"
ecs.import "ant.timer"
ecs.import "ant.scene"
ecs.import "ant.serialize"
ecs.import "ant.objcontroller"
ecs.import "ant.profile"
ecs.import "ant.animation"
ecs.import "ant.geometry"
ecs.import "ant.math.adapter"

local math 		= import_package "ant.math"
local renderpkg = import_package "ant.render"
local ms 		= math.stack
local camerautil= renderpkg.camera
local renderutil= renderpkg.util
local aniutil 	= import_package "ant.animation".util
 
ecs.tag "sampleobj"

local model_ed_sys = ecs.system "model_editor_system"

--model_ed_sys.depend "character_controller"
model_ed_sys.dependby "viewport_detect_system"
model_ed_sys.dependby "camera_controller"
model_ed_sys.dependby "renderbone_system"
model_ed_sys.dependby "state_machine"
model_ed_sys.dependby "skinning_system"

--model_ed_sys.dependby "render_mesh_bounding"
model_ed_sys.dependby "primitive_filter_system"
model_ed_sys.dependby "render_system"
model_ed_sys.dependby "pickup_system"
model_ed_sys.dependby "shadow_maker11"
model_ed_sys.dependby "debug_shadow_maker"

-- luacheck: globals main_dialog
-- luacheck: globals iup
local function get_ani_cursor(slider)
	assert(tonumber(slider.MIN) == 0)
	assert(tonumber(slider.MAX) == 1)
	return tonumber(slider.VALUE)
end

local function update_animation_ratio(eid, cursor_pos)
	local e = world[eid]	
	local anicomp = e.animation
	if anicomp then
		anicomp.ratio = cursor_pos
	end
end

local sample_eid

local function sample_entity()
	if sample_eid then
		return world[sample_eid]
	end
end

local function dlg_item(name)	
	return iup.GetDialogChild(main_dialog(), name)
end

local function enable_sample_visible()
	if sample_eid then
		local sample = world[sample_eid]
		if sample then
			local sample_shower = dlg_item("SHOWSAMPLE")
			sample.can_render = sample_shower.VALUE ~= "OFF"
		end
	end
end

local function enable_sample_boundingbox()
	local sample = sample_entity()
	if sample then
		local bounding = dlg_item("SHOWSAMPLEBOUNDING")
		sample.can_show_bounding = bounding.VALUE ~= "OFF"
	end
end

local function enable_using_lightview()
	local main_queue = world:first_entity "main_queue"
	local shadow_queue = world:first_entity "shadow"

	local maincamera = main_queue.camera
	main_queue.camera = shadow_queue.camera
	shadow_queue.camera = maincamera
end

local function enable_bones_visible()
	if sample_eid then
		local sample =world[sample_eid]
		if sample then
			local bone_shower = dlg_item("SHOWBONES")
			if bone_shower.VALUE ~= "OFF" then
				assert(sample.debug_skeleton == nil)
				world:add_component(sample_eid, "debug_skeleton", true)
			else
				if sample.debug_skeleton then
					world:remove_component(sample_eid, "debug_skeleton")
				end
			end
		end
	end
end

local function check_create_sample_entity(skepath, anipaths, smpath)
	if not fs.exists(smpath) then
		iup.Message("Error", string.format("invalid path : %s", smpath))
		return
	end
	if sample_eid then
		world:remove_entity(sample_eid)
	end
	sample_eid = util.create_sample_entity(world, skepath, anipaths, smpath)
	enable_sample_visible()	
end

local function get_sel_ani()
	local dlg = main_dialog()
	local aniview = iup.GetDialogChild(dlg, "ANIVIEW").owner
	return aniview:get()
end

local function update_static_duration_value()
	if sample_eid then
		local e = world[sample_eid]
		local ani = e.animation
		if ani then 
			local anipath = get_sel_ani()
			local anihandle = nil
			for _, ani in ipairs(ani.anilist) do
				if ani.ref_path == fs.path(anipath) then
					anihandle = ani.handle
				end
			end

			if anihandle then
				local duration = anihandle:duration()
				local dlg = main_dialog()
				local static_duration_value = iup.GetDialogChild(dlg, "STATIC_DURATION")
				static_duration_value.TITLE = string.format("Time(%.2f ms)", duration * 1000)
			else
				print("not found ani handle, select animation resource:%s", anipath)
			end
		end
	end
end

local function update_duration_text(cursorpos)		
	local dlg = main_dialog()
	local duration_value = iup.GetDialogChild(dlg, "DURATION")
	if duration_value == nil then
		return 
	end

	local sample = sample_entity()
	if sample == nil then
		return 
	end
	asset(false, "animation need rewrite!")
end

local function slider_value_chaged(slider)
	if sample_eid then
		local cursorpos = get_ani_cursor(slider)
		update_duration_text(cursorpos)
		update_animation_ratio(sample_eid, cursorpos)
	end
end

local function init_debug()
	
end

local function init_paths_ctrl()
	local dlg = main_dialog()

	--default value
	local skeinputer = iup.GetDialogChild(dlg, "SKEINPUTER").owner
	local sminputer = iup.GetDialogChild(dlg, "SMINPUTER").owner
	local aniview = iup.GetDialogChild(dlg, "ANIVIEW").owner

	-- local skepath = fs.path "meshes/skeleton/human_skeleton.ozz"
	-- skeinputer:set_input(skepath:string())

	-- local smfilename = fs.path "meshes/mesh.ozz"	
	-- sminputer:set_input(smfilename:string())

	-- assert(aniview:count() == 0)
	-- aniview:add(fs.path "meshes/animation/animation1.ozz")
	-- aniview:add(fs.path "meshes/animation/animation2.ozz")

	sminputer:set_input("/pkg/ant.resources.binary/meshes/female/female.ozz")
	skeinputer:set_input("/pkg/ant.resources.binary/meshes/female/skeleton.ozz")
	
	assert(aniview:count() == 0)
	aniview:add("/pkg/ant.resources.binary/meshes/female/animations/idle.ozz")
	aniview:add("/pkg/ant.resources.binary/meshes/female/animations/walking.ozz")
	aniview:add("/pkg/ant.resources.binary/meshes/female/animations/running.ozz")
	
	local blender = iup.GetDialogChild(dlg, "BLENDER").owner
	aniview:set_blender(blender)

	local change_cb = function ()		
		local skepath = fs.path(skeinputer:get_input())
		local smpath = fs.path(sminputer:get_input())

		local anipaths = {}
		for i=1, aniview:count() do
			anipaths[#anipaths+1] = fs.path(aniview:get(i))
		end
		check_create_sample_entity(skepath, anipaths, smpath)
	end

	skeinputer:add_changed_cb(change_cb)
	sminputer:add_changed_cb(change_cb)

	change_cb()
end

local function init_check_shower()
	local checkers = {
		SHOWBONES=enable_bones_visible,
		SHOWSAMPLE=enable_sample_visible,
		SHOWSAMPLEBOUNDING=enable_sample_boundingbox,
		USELIGHTVIEW=enable_using_lightview,
	}

	for k, v in pairs(checkers) do
		local checker = dlg_item(k)
		checker.action = function () v() end
	end
end

local function init_blend_ctrl()
	local dlg = main_dialog()
	local blender = dlg_item("BLENDER").owner
	blender:observer_blend("blend", function (blendlist, type)
		local sample = sample_entity()
		if sample then
			local anicomp = sample.animation
			if anicomp then

			end
		end
	end)
end

local function init_lighting()
	local lu = renderpkg.light
	lu.create_directional_light_entity(world, nil, {1,1,1,1}, 2, {123.4, -34.22,-28.2})
end

local function focus_sample()
	if sample_eid then		
		if camerautil.focus_selected_obj(world, sample_eid) then
			return 
		end	
	end

	camerautil.focus_point(world, {0, 0, 0})
end

local function init_ik()
	local sample = sample_entity()
	if sample then
		assert(sample.ik == nil)
		local ske = assert(sample.skeleton)

		assert(sample.animation)

		local skehandle = assetmgr.get_skeleton(ske.ref_path).handle

		world:add_component(sample_eid, "ik", {
			target = {1, 2, 0, 1},
			pole_vector = {0, 1, 0, 0},
			mid_axis = {0, 0, 1, 0},
			weight = 1.0,
			soften = 0.5,
			twist_angle = 0,

			start_joint = skehandle:joint_index("shoulder")
			mid_joint = skehandle:joint_index("forearm")
			end_joint = skehandle:joint_index("wrist")
		})

		local ik = sample.ik
		ik.enable = true
	end
end


local function init_scene()
	local computil = renderpkg.components
	computil.create_grid_entity(world, "grid", 16, 16, 1)
	computil.create_plane_entity(world, {0.5, 0.5, 0.5, 1})
end

-- luacheck: ignore self
function model_ed_sys:init()	
	renderutil.create_main_queue(world, world.args.fb_size, ms({1, 1, -1}, "nT"), {1, 1, -1})

	init_lighting()

	--init_ik()

	init_scene()
	focus_sample()

	local sample = sample_entity()
	--setmetatable(sample.transform)
	if sample then
		local anicomp = sample.animation
		aniutil.play_animation(anicomp, anicomp.pose_state.pose)
	end
end