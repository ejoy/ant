local ecs = ...
local world = ecs.world

-- luacheck: ignore param
ecs.import "timer"
ecs.import "render.math3d.math_component"

local ani = ecs.component "animation" {
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
local ske = ecs.component "skeleton" {
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
anisystem.singleton "math_stack"

local ani_module = require "hierarchy.animation"

function anisystem:update()
	for _, eid in world:each("animation") do
		local e = world[eid]
		local skecomp = assert(e.skeleton)
		local ske = assert(skecomp.assetinfo).handle

		local anicomp = assert(e.animation)
		local ani = assert(anicomp.assetinfo).handle

		ani_module.motion(ske, ani, anicomp.sampling_cache, anicomp.ratio)
	end
end

