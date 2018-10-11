local ecs = ...
local world = ecs.world

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

-- -- separate animation and skeleton to 2 component, 
-- -- skeleton component will corresponding to some system that do not need animation
-- local ske = ecs.component "skeleton" {
-- 	path = {
-- 		type = "userdata",
-- 		default = "",
-- 		save = function (v, param)
-- 			assert(false, "not implement skeleton save")
-- 		end,
-- 		load = function (v, param)
-- 			assert(false, "not implement skeleton load")
-- 		end
-- 	}
-- }


local anisystem = ecs.system "animation_system"
anisystem.singleton "timer"
anisystem.singleton "math_stack"

local ani_module = "hierarchy.animation"

function anisystem:update()
	local timer = self.timer
	local delta = timer.delta

	for _, eid in world:each("animation") do
		local e = world[eid]
		local skeleton = assert(e.hierarchy)
		local animation = e.animation

		ani_module.motion(skeleton, animation, 0.1)
	end

end

