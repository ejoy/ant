local ecs = ...

ecs.component_alias("animation_birth", "string")

local m = ecs.transform "animation_birth"

function m.process(e)
	e.animation.current = {
		animation = e.animation.anilist[e.animation_birth],
		ratio = 0,
	}
end
