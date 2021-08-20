local ecs = ...
local w = ecs.world.w

local m = ecs.system "animation_birth"

function m:entity_init()
	for e in w:select "INIT animation_birth:in animation:in _animation:in" do
		local name = e.animation_birth
		e._animation._current = {
			animation = e.animation[name],
			event_state = {
				next_index = 1,
				keyframe_events = e.keyframe_events and e.keyframe_events[name] or {}
			},
			clip_state = { current = {clip_index = 1}, clips = e.anim_clips and e.anim_clips[name] or {}},
			play_state = { ratio = 0.0, previous_ratio = 0.0, speed = 1.0, play = true, loop = true}
		}
	end
end
