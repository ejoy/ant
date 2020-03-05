local ecs = ...

local m = ecs.policy "animation_controller.birth"
m.require_component "animation"
m.require_component "animation_birth"
m.require_transform "animation_birth"

ecs.component_alias("animation_birth", "string")

local m = ecs.transform "animation_birth"
m.input "animation_birth"
m.output "animation"

function m.process(e)
	e.animation.current = {
		animation = e.animation.anilist[e.animation_birth],
		ratio = 0,
	}
end

