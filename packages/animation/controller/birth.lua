local ecs = ...

local m = ecs.transform "animation_birth"

function m.process_entity(e)
	e._animation._current = {
		animation = e.animation[e.animation_birth],
		event_state = {
			next_index = 1,
			keyframe_events = e.keyframe_events and e.keyframe_events[e.animation_birth] or {}
		},
		clip_state = { current = {clip_index = 1}, clips = e.anim_clips and e.anim_clips[name] or {}},
		play_state = { ratio = 0.0, previous_ratio = 0.0, speed = 1.0, play = true, loop = true}
	}
end
