local ecs = ...
local world = ecs.world

local model_ed_sys = ecs.system "model_editor_system"

-- luacheck: globals model_windows
local windows = model_windows()

local assetmgr = require "asset"
local comp_util = require "component.util"
local fu = require "filesystem.util"

local function create_sample_entity(skepath, anipath, meshpath)
	local eid = world:new_entity("position", "scale", "rotation",
	"skeleton", "animation", 
	"name", "can_render")

	local e = world[eid]
	e.skeleton.builddata = assetmgr.load(skepath)
	e.animation.handle = assetmgr.load(anipath)

	comp_util.load_mesh(e, meshpath)

	local smaplemaerial = "mem://sample.material"
	fu.write_to_file(smaplemaerial, [[
		shader = {
			vs = "mesh/vs_meshani",
			fs = "mesh/fs_meshbumpex",
		}

		state = "default.state"

		properties = {

		}
	]])

	comp_util.load_material(e, "")

	return eid
end

-- luacheck: ignore self
function model_ed_sys:init()
	local sample_eid

	local skepath_ctrl = windows.ske_path
	local anipath_ctrl = windows.ani_path

	local function check_create_sample_entity(sc, ac)
		local anipath = ac.VALUE
		local skepath = sc.VALUE
		if 	anipath and anipath ~= "" and
			skepath and skepath ~= "" then
				if sample_eid then
					world:remove_entity(sample_eid)
				end

			sample_eid = create_sample_entity(skepath, anipath)
		end
	end

	function skepath_ctrl:VALUECHANGED_CB()
		check_create_sample_entity(self, anipath_ctrl)
		return 0
	end

	function anipath_ctrl:VALUECHANGED_CB()
		check_create_sample_entity(skepath_ctrl, self)
		return 0
	end
end

local animodule = require "hierarchy.animation"

function model_ed_sys:update()
	local silder = windows.anitime_silder
	local time = tonumber(silder.VALUE)

	for _, eid in world:each("animation") do
		local e = world[eid]
		local ske = assert(e.skeleton).builddata
		local ani = assert(e.animation).handle

		local duration = ani:duration()
		local delta = time / duration
		animodule.motion(ske, ani, delta)
	end
end