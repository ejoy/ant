local ecs = ...

local m = ecs.transform "animation_birth"

function m.process_prefab(e)
	e.animation._current = {
		animation = e.animation.anilist[e.animation_birth],
		ratio = 0,
	}
end
