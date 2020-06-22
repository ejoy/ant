local ecs = ...

local m = ecs.transform "animation_birth"

function m.process_entity(e)
	e._animation._current = {
		animation = e.animation.anilist[e.animation_birth],
		ratio = 0,
	}
end
