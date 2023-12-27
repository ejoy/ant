local ecs 	= ...
local world = ecs.world
local w 	= world.w

import_package "ant.math"

local ani_sys 		= ecs.system "animation_system"
local timer 		= ecs.require "ant.timer|timer_system"
local audio 		= import_package "ant.audio"
local fmod
if world.__EDITOR__ then
	fmod = require "fmod"
end

local function process_keyframe_event(task)
	if not task then
		return
	end
	local event_state = task.event_state
	local all_events = event_state.keyframe_events
	local current_events = all_events and all_events[event_state.next_index] or nil
	if not current_events then return end

	local current_time = task.play_state.ratio * task.animation:duration()
	local _
	_ = type(current_time) == "number" or error("invalid current time :" .. task.keyframe_events.filename)
	_ = type(current_events.time) == "number" or error("invalid event time :" .. task.keyframe_events.filename)

	if current_time < current_events.time and event_state.finish then
		event_state.next_index = 1
		event_state.finish = false
	end
	while not event_state.finish and current_events.time <= current_time do
		for _, event in ipairs(current_events.event_list) do
			if event.event_type == "Sound" then
				if world.__EDITOR__ then
					if event.sound_event ~= '' then
						fmod.play(world.sound_event_list[event.sound_event])
					end
				else
					audio.play(event.sound_event)
				end
			elseif event.event_type == "Effect" then
				-- if event.effect then
				-- 	local e <close> = world:entity(event.effect, "efk:in")
				-- 	iefk.play(e)
				-- elseif event.asset_path ~= "" then
				-- 	event.effect = iefk.create(event.asset_path, {
				-- 		scene = { parent = task.slot_eid and task.slot_eid[event.link_info.slot_name] or nil},
				-- 		group = task.group,
				-- 		visible_state = "main_queue",
				-- 	})
				-- end
				-- world:pub {"keyframe_event", "effect", event.asset_path, task.context}
			elseif event.event_type == "Message" then
				world:pub {"keyframe_event", "message", task.context}
			end
		end
		event_state.next_index = event_state.next_index + 1
		if event_state.next_index > #all_events then
			event_state.next_index = #all_events
			event_state.finish = true
			break
		end
		current_events = all_events[event_state.next_index]
	end
end

local iani = ecs.require "ant.anim_ctrl|state_machine"

function ani_sys:animation_state()
	local delta_time = timer.delta()
	for e in w:select "playing anim_ctrl:in" do
		local ctrl = e.anim_ctrl
		if ctrl.animation then
			iani.step(e, delta_time * 0.001)
		end
	end
end

function ani_sys:data_changed()
	for e in w:select "playing anim_ctrl:in" do
		process_keyframe_event(e.anim_ctrl)
	end
end

local event_animation = world:sub{"animation_event"}

function ani_sys:entity_init()
	for e in w:select "INIT animation:in animation_birth:new anim_ctrl:new eid:in playing?out" do
		e.anim_ctrl = {}
		e.animation_birth = ""
		e.anim_ctrl.keyframe_events = {}
		local events = e.anim_ctrl.keyframe_events
		for key, value in pairs(e.animation.status) do
			--TODO: auto load event
			events[key] = {}--load_events(tostring(value))
		end
		local anim_name = e.animation_birth
		e.anim_ctrl.animation = anim_name
		e.anim_ctrl.event_state = { next_index = 1, keyframe_events = events[anim_name] }
		e.anim_ctrl.play_state = e.anim_ctrl.play_state or {
			ratio = 0.0,
			previous_ratio = 0.0,
			speed = 1.0,
			play = (anim_name ~= ""),
			loop = false,
			manual_update = false
		}
		e.playing = e.anim_ctrl.play_state.play
		world:pub {"animation_event", "set_time", e.eid, 0}
	end
end

function ani_sys:entity_ready()
	for _, what, e, p0, p1 in event_animation:unpack() do
		if what == "step" then
			iani.step(e, p0, p1)
		elseif what == "set_time" then
			iani.set_time(e, p0)
		end
	end
end
