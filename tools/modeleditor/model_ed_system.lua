local ecs = ...
local world = ecs.world

-- runtime
ecs.import "render.camera.camera_component"
ecs.import "render.entity_rendering_system"
ecs.import "render.view_system"

-- scene
ecs.import "scene.cull_system"

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
			vs = "mesh/vs_mesh_bump",
			fs = "mesh/fs_mesh_bumpex",
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
	--meshpath_ctrl.VALUE=fu.write_to_file("mem://mesh.mesh", [[mesh_path = "meshes/mesh"]])
	meshpath_ctrl.VALUE = "meshes/mesh.ozz"
	check_create_sample_entity(skepath_ctrl, anipath_ctrl, meshpath_ctrl)

	local slider = windows.anitime_slider
	
	function slider:valuechanged_cb()
		update_animation_ratio(sample_eid, get_ani_cursor(self))
	end

	update_animation_ratio(sample_eid, get_ani_cursor(slider))
end

-- luacheck: ignore self
function model_ed_sys:init()
	local ms = self.math_stack
	init_control(ms)

	local maincamera = world:first_entity("main_camera")
	assert(maincamera.primitive_filter).no_lighting = true
end