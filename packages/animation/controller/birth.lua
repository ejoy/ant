local ecs = ...

local m = ecs.transform "animation_birth"

function m.process_entity(e)
	e._animation._current = {
		animation = e.animation[e.animation_birth],
		event_state = {
			next_index = 1,
			keyframe_events = e.keyframe_events and e.keyframe_events[e.animation_birth] or {}
		},
		ratio = 0,
	}
end
