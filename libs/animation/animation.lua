local ecs = ...
local world = ecs.world

local ani = ecs.component "animation" {
	path = {
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

-- separate animation and skeleton to 2 component, 
-- skeleton component will corresponding to some system that do not need animation
local ske = ecs.component "skeleton" {
	path = {
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


local anisystem = ecs.system "animationsystem"
anisystem.singleton "timer"
anisystem.singleton "math_stack"

local ani_module = "hierarchy.animation"

function anisystem:update()
	local timer = self.timer
	local delta = timer.delta

	for _, eid in world:each("animation") do
		local e = world[eid]
		local skeleton = assert(e.skeleton)
		local animation = e.animation

		--ani_module.merge(assert(skeleton.handle), animation.anilist, animation.aniweight, delta)
	end

end

