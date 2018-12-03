local ecs = ...
local world = ecs.world

-- runtime
ecs.import "render.camera.camera_component"
ecs.import "render.entity_rendering_system"
ecs.import "render.view_system"


-- lighting
ecs.import "render.light.light"

-- serialize
ecs.import "serialize.serialize_system"

-- scene
ecs.import "scene.cull_system"
ecs.import "scene.filter.filter_system"
ecs.import "scene.filter.lighting_filter"

-- animation
ecs.import "animation.skinning.skinning_system"
ecs.import "animation.animation"
ecs.import "physic.rigid_body"

-- editor
ecs.import "editor.ecs.camera_controller"
ecs.import "editor.ecs.pickup_system"
ecs.import "editor.ecs.render.widget_system"

-- editor elements
ecs.import "editor.ecs.general_editor_entities"
ecs.import "editor.ecs.debug.debug_drawing"
ecs.import "tools.modeleditor.accessory_system"

local ms = require "math.stack"
local util = require "tools.modeleditor.util"
local physicobjs = require "tools.modeleditor.physicobj"
local assetmgr = require "asset"

ecs.tag "sampleobj"

local model_ed_sys = ecs.system "model_editor_system"
model_ed_sys.singleton "debug_object"

model_ed_sys.depend "camera_init"

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

local function init_control()
	local dlg = main_dialog()
	local skepath_ctrl = iup.GetDialogChild(dlg, "SKE_PATH")
	local anipath_ctrl = iup.GetDialogChild(dlg, "ANI_PATH")
	local meshpath_ctrl = iup.GetDialogChild(dlg, "SM_PATH")

	local function check_create_sample_entity(sc, ac, mc)
		local anipath = ac.VALUE
		local skepath = sc.VALUE
		local skinning_meshpath = mc.VALUE

		local function check_path_valid(pp)
			if pp == nil or pp == "" then
				return false
			end

			if not assetmgr.find_valid_asset_path(pp) then
				iup.Message("Error", string.format("invalid path : %s", pp))
				return false
			end

			return true
		end

		-- only skinning meshpath is needed!
		if check_path_valid(skinning_meshpath) then			
			if sample_eid then
				world:remove_entity(sample_eid)
			end

			sample_eid = util.create_sample_entity(world, skepath, anipath, skinning_meshpath)
		end
	end

	function skepath_ctrl:killfocus_cb()		
		check_create_sample_entity(self, anipath_ctrl, meshpath_ctrl)
		return 0
	end
	
	function anipath_ctrl:killfocus_cb()
		check_create_sample_entity(skepath_ctrl, self, meshpath_ctrl)
		return 0
	end

	function meshpath_ctrl:killfocus_cb()
		check_create_sample_entity(skepath_ctrl, anipath_ctrl, self)
	end

	-- skepath_ctrl.VALUE=fu.write_to_file("cache/ske.ske", [[path="meshes/skeleton/skeleton"]])
	-- anipath_ctrl.VALUE=fu.write_to_file("cache/ani.ani", [[path="meshes/animation/animation_base"]])
	meshpath_ctrl.VALUE = "meshes/mesh.ozz"
	check_create_sample_entity(skepath_ctrl, anipath_ctrl, meshpath_ctrl)

	local slider = iup.GetDialogChild(dlg, "ANITIME_SLIDER")

	local function update_static_duration_value()
		if sample_eid then
			local e = world[sample_eid]
			local ani = e.animation
			if ani then 
				local anihandle = ani.assetinfo.handle
				
				local duration = anihandle:duration()			
				local static_duration_value = iup.GetDialogChild(dlg, "STATIC_DURATION")
				static_duration_value.TITLE = string.format("Time(%.2f ms)", duration * 1000)
			end
		end
	end

	update_static_duration_value()

	local duration_value = iup.GetDialogChild(dlg, "DURATION")
	function duration_value:killfocus_cb()
		local duration = tonumber(self.VALUE)

		if sample_eid then
			local e = world[sample_eid]
			local anicomp = e.animation
			if anicomp then
				local anihandle = anicomp.assetinfo.handle
				local aniduration = anihandle:duration()
				local ratio = math.min(math.max(0, duration / aniduration), 1)
				anicomp.ratio = ratio
			end
		end
	end
	
	local function update_duration_text(cursorpos)		
		if duration_value == nil then
			return 
		end

		local sample_e = world[sample_eid]		
		if sample_e == nil then
			return nil
		end

		local anicomp = sample_e.animation
		if anicomp then
			local ani_assetinfo = anicomp.assetinfo
			if ani_assetinfo then
				local ani_handle = ani_assetinfo.handle
				local duration_pos = ani_handle:duration() * cursorpos
				duration_value.VALUE = string.format("%2f", duration_pos)
			end
		end
	end

	local function slider_value_chaged(slider)
		local cursorpos = get_ani_cursor(slider)
		update_duration_text(cursorpos)
		update_animation_ratio(sample_eid, cursorpos)
	end

	function slider:valuechanged_cb()
		slider_value_chaged(self)
	end

	slider_value_chaged(slider)

	iup.Map(dlg)
end

local function init_lighting()
	local lu = require "render.light.util"
	local leid = lu.create_directional_light_entity(world)
	local lentity = world[leid]
	local lightcomp = lentity.light
	lightcomp.color = {1,1,1,1}
	lightcomp.intensity = 2.0
	ms(lentity.rotation, {123.4, -34.22,-28.2}, "=")
end

local function focus_sample()
	if sample_eid then		
		world:change_component(sample_eid, "focus_selected_obj")
		world.notify()
	end
end

-- luacheck: ignore self
function model_ed_sys:init()	
	init_control()
	init_lighting()

	physicobjs.create_plane_entity(world)

	focus_sample()
end