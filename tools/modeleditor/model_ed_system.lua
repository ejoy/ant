local ecs = ...
local world = ecs.world

local model_ed_sys = ecs.system "model_editor_system"

model_ed_sys.dependby "animation_system"

-- luacheck: globals model_windows
-- luacheck: globals iup
local windows = model_windows()

local assetmgr = require "asset"
local comp_util = require "render.components.util"
local fu = require "filesystem.util"

local function create_sample_entity(skepath, anipath, meshpath)
	local eid = world:new_entity("position", "scale", "rotation",
	"skeleton", "animation", "mesh", "material",
	"name", "can_render")

	local e = world[eid]
	e.name = "animation_test"

	comp_util.load_animation(e, anipath)
	comp_util.load_skeleton(e, skepath)
	comp_util.load_mesh(e, meshpath)

	local smaplemaerial = "mem://sample.material"
	fu.write_to_file(smaplemaerial, [[
		shader = {
			vs = "mesh/vs_meshani",
			fs = "mesh/fs_mesh_bumpex",
		}

		state = "default.state"

		properties = {

		}
	]])

	comp_util.load_material(e, {smaplemaerial})
	return eid
end

local function get_ani_playtime_in_second(slider)	
	local time_in_ms = tonumber(slider.VALUE)
	return time_in_ms / 1000
end

local function update_animation_ratio(eid, time_in_second)
	local e = world[eid]
	local anicomp = assert(e.animation)
	local hani = assert(anicomp.assetinfo).handle

	local duration = hani:duration()
	anicomp.ratio = time_in_second / duration
end

local function init_control()
	local sample_eid

	local skepath_ctrl = windows.ske_path
	local anipath_ctrl = windows.ani_path
	local meshpath_ctrl = windows.mesh_path

	local function check_create_sample_entity(sc, ac, mc)
		local anipath = ac.VALUE
		local skepath = sc.VALUE
		local meshpath = mc.VALUE

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
			check_path_valid(meshpath) then
			
			if sample_eid then
				world:remove_entity(sample_eid)
			end

			sample_eid = create_sample_entity(skepath, anipath, meshpath)
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
	meshpath_ctrl.VALUE=fu.write_to_file("mem://mesh.mesh", [[mesh_path = "meshes/mesh"]])
	check_create_sample_entity(skepath_ctrl, anipath_ctrl, meshpath_ctrl)

	local slider = windows.anitime_slider
	
	function slider:valuechanged_cb()
		update_animation_ratio(sample_eid, get_ani_playtime_in_second(self))
	end

	update_animation_ratio(sample_eid, get_ani_playtime_in_second(slider))
end

-- luacheck: ignore self
function model_ed_sys:init()
	init_control()
end