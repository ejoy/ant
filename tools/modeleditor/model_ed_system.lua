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
ecs.import "scene.filter_system"

-- animation
ecs.import "animation.skinning.skinning_system"
ecs.import "animation.animation"

-- editor
ecs.import "editor.ecs.camera_controller"
ecs.import "editor.ecs.pickup_system"

-- editor elements
ecs.import "editor.ecs.general_editor_entities"

local model_ed_sys = ecs.system "model_editor_system"
model_ed_sys.singleton "math_stack"
model_ed_sys.depend "camera_init"

-- luacheck: globals model_windows
-- luacheck: globals iup
local windows = model_windows()

local assetmgr = require "asset"
local comp_util = require "render.components.util"
local fu = require "filesystem.util"

local modelutil = require "modelloader.util"

local function load_mesh_assetinfo(skinning_mesh_comp)
	local bgfx = require "bgfx"
	local skinning_mesh = skinning_mesh_comp.assetinfo.handle

	local decls = {}
	local vb_handles = {}
	local vb_data = {"!", "", 1}
	for _, type in ipairs {"dynamic", "static"} do
		local layout = skinning_mesh:layout(type)
		local decl = modelutil.create_decl(layout)
		table.insert(decls, decl)

		local buffer, size = skinning_mesh:buffer(type)
		vb_data[2], vb_data[3] = buffer, size
		if type == "dynamic" then
			table.insert(vb_handles, bgfx.create_dynamic_vertex_buffer(vb_data, decl))
		elseif type == "static" then
			table.insert(vb_handles, bgfx.create_vertex_buffer(vb_data, decl))
		end
	end

	local function create_idx_buffer()
		local idx_buffer, ib_size = skinning_mesh:index_buffer()	
		if idx_buffer then			
			return bgfx.create_index_buffer({idx_buffer, ib_size})
		end

		return nil
	end

	local ib_handle = create_idx_buffer()

	return {
		handle = {
			groups = {
				{
					vb = {
						decls = decls,
						handles = vb_handles,
					},
					ib = {
						handle = ib_handle,
					}
				}
			}
		},			
	}
end

local function create_sample_entity(ms, skepath, anipath, skinning_meshpath)
	local eid = world:new_entity("position", "scale", "rotation",
	"skeleton", "animation", "skinning_mesh", 
	"mesh", "material",
	"name", "can_render")

	local e = world[eid]
	e.name.n = "animation_test"

	local mu = require "math.util"
	mu.identify_transform(ms, e)

	comp_util.load_skeleton(e, skepath)
	comp_util.load_animation(e, anipath)

	do
		local skehandle = assert(e.skeleton.assetinfo.handle)
		local numjoints = #skehandle
		e.animation.sampling_cache = comp_util.new_sampling_cache(#skehandle)

		local anihandle = e.animation.assetinfo.handle
		anihandle:resize(numjoints)
	end
	

	comp_util.load_skinning_mesh(e, skinning_meshpath)	
	e.mesh.assetinfo = load_mesh_assetinfo(e.skinning_mesh)

	local smaplemaerial = "mem://sample.material"
	fu.write_to_file(smaplemaerial, [[
		shader = {
			vs = "mesh/vs_color_lighting",
			fs = "mesh/fs_color_lighting",
		}

		state = "default.state"

		properties = {

		}
	]])

	comp_util.load_material(e, {smaplemaerial})
	return eid
end

local function get_ani_cursor(slider)
	assert(tonumber(slider.MIN) == 0)
	assert(tonumber(slider.MAX) == 1)
	return tonumber(slider.VALUE)
end

local function update_animation_ratio(eid, cursor_pos)
	local e = world[eid]
	local anicomp = assert(e.animation)	
	anicomp.ratio = cursor_pos
end

local function init_control(ms)
	local sample_eid

	local skepath_ctrl = windows.ske_path
	local anipath_ctrl = windows.ani_path
	local meshpath_ctrl = windows.mesh_path

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

		if check_path_valid(anipath) and
			check_path_valid(skepath) and
			check_path_valid(skinning_meshpath) then
			
			if sample_eid then
				world:remove_entity(sample_eid)
			end

			sample_eid = create_sample_entity(ms, skepath, anipath, skinning_meshpath)
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

	skepath_ctrl.VALUE=fu.write_to_file("mem://ske.ske", [[path="meshes/skeleton/skeleton"]])
	anipath_ctrl.VALUE=fu.write_to_file("mem://ani.ani", [[path="meshes/animation/animation_base"]])	
	meshpath_ctrl.VALUE = "meshes/mesh.ozz"
	check_create_sample_entity(skepath_ctrl, anipath_ctrl, meshpath_ctrl)

	local slider = windows.anitime_slider
	local dlg = iup.GetDialog(slider)

	local function update_static_duration_value()
		if sample_eid then
			local e = world[sample_eid]
			local anihandle = assert(e.animation.assetinfo).handle
			
			local duration = anihandle:duration()			
			local static_duration_value = iup.GetDialogChild(dlg, "STATIC_DURATION")
			static_duration_value.TITLE = string.format("Time(%.2f ms)", duration * 1000)
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

-- luacheck: ignore self
function model_ed_sys:init()
	local ms = self.math_stack
	init_control(ms)

	local lu = require "render.light.util"
	local leid = lu.create_directional_light_entity(world)
	local lentity = world[leid]
	local lightcomp = lentity.light.v
	lightcomp.color = {1,1,1,1}
	lightcomp.intensity = 2.0
	ms(lentity.rotation.v, {123.4, -34.22,-28.2}, "=")

	local maincamera = world:first_entity("main_camera")
	--assert(maincamera.primitive_filter).no_lighting = true
end