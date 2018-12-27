local ecs = ...
local world = ecs.world

-- luacheck: ignore param
ecs.import "timer"

local ani = ecs.component_struct "animation" {
	ref_path = {
		type = "userdata",
		default = "",
		save = function (v, param)
			assert(false, "not implement animation save")
		end,
		load = function (v, param)
			assert(false, "not implement animation load")
		end
	},	
}

function ani:init()
	self.ratio = 0
end

-- separate animation and skeleton to 2 component, 
-- skeleton component will corresponding to some system that do not need animation
local ske = ecs.component_struct "skeleton" {
	ref_path = {
		type = "userdata",
		default = "",
		save = function (v, param)
			assert(false, "not implement skeleton save")
		end,
		load = function (v, param)
			assert(false, "not implement skeleton load")
		end
	}
}


local anisystem = ecs.system "animation_system"
anisystem.singleton "timer"

local ani_module = require "hierarchy.animation"

function anisystem:update()
	for _, eid in world:each("animation") do
		local e = world[eid]
		local skecomp = assert(e.skeleton)
		local ske = assert(skecomp.assetinfo).handle

		local anicomp = assert(e.animation)
		local anilist = assert(anicomp.anilist)
		ani_module.motion(ske, anicomp.ratio, anilist, "blend", anicomp.aniresult)
	end
end

