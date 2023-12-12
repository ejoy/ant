local ecs 	= ...
local world = ecs.world
local w 	= world.w

import_package "ant.math"
local assetmgr 		= import_package "ant.asset"
local serialize = import_package "ant.serialize"
local aio       = import_package "ant.io"
local ozz 	= require "ozz"

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

local iani = ecs.require "ant.animation|state_machine"

function ani_sys:sample_animation_pose()
	local delta_time = timer.delta()
	for e in w:select "playing pose_dirty?out animation:in anim_ctrl:in" do
		--w:readall(eid)
		local ctrl = e.anim_ctrl
		if ctrl.animation then
			iani.step(e, delta_time * 0.001)
		end
	end
end

function ani_sys:do_refine()
end

function ani_sys:end_animation()
	for e in w:select "pose_dirty:out animation:in playing?out anim_ctrl:in" do
		ozz.LocalToModelJob(e.animation.ozz.skeleton, e.animation.locals, e.animation.models)
		e.playing = e.anim_ctrl.play_state.play
		e.pose_dirty = false
	end
end

function ani_sys:data_changed()
	for e in w:select "playing anim_ctrl:in" do
		process_keyframe_event(e.anim_ctrl)
	end
end

function ani_sys:component_init()
	for e in w:select "INIT animation:update" do
		local data = assetmgr.resource(e.animation)
		local skeleton = data.skeleton
		local n = skeleton:num_joints()
		e.animation = {
			ozz = data,
			locals = nil,
			models = ozz.MatrixVector(n),
		}
	end

	for e in w:select "INIT animation:in meshskin:update" do
		local skin = assetmgr.resource(e.meshskin)
		local n = e.animation.ozz.skeleton:num_joints()
		local count = n
		if skin.joint_remap and #skin.joint_remap ~= n then
			--error(("joint_remap length: %d, skeleton length: %d"):format(#skin.joint_remap, n))
			count = #skin.joint_remap
		end
		if count > 64 then
			error(("skinning matrices are too large, max is 128, %d needed"):format(n))
		end
		e.meshskin = {
			skin = skin,
			skinning_matrices = ozz.MatrixVector(count),
			prev_skinning_matrices = ozz.MatrixVector(count)
		}
	end

	for e in w:select "INIT anim_ctrl:in animation:in animation_birth:in eid:in" do
		e.anim_ctrl.keyframe_events = {}
		local events = e.anim_ctrl.keyframe_events
		for key, value in pairs(e.animation.ozz.animations) do
			--TODO: auto load event
			events[key] = {}--load_events(tostring(value))
		end
		local anim_name = e.animation_birth
		e.anim_ctrl.animation = e.animation.ozz.animations[anim_name]
		e.anim_ctrl.event_state = { next_index = 1, keyframe_events = events[anim_name] }
		e.anim_ctrl.play_state = e.anim_ctrl.play_state or {
			ratio = 0.0,
			previous_ratio = 0.0,
			speed = 1.0,
			play = (anim_name ~= ""),
			loop = true,
			manual_update = false
		}
		world:pub {"animation_event", "set_time", e.eid, 0}
	end
end

local event_animation = world:sub{"animation_event"}

function ani_sys:entity_init()
	local animation
	local anim_ctrl
	for e in w:select "INIT animation?in anim_ctrl?in slot?in eid:in pose_dirty?out boneslot?out" do
		if e.animation and e.anim_ctrl then
			animation = e.animation
			anim_ctrl = e.anim_ctrl
			e.pose_dirty = true
		elseif e.slot then
			local slot = e.slot
			if slot.joint_name and animation and animation.ozz.skeleton then
				slot.joint_index = animation.ozz.skeleton:joint_index(slot.joint_name)
				if slot.joint_index then
					e.boneslot = true
				end
			end
			slot.animation = animation
			if anim_ctrl then
				if not anim_ctrl.slot_eid then
					anim_ctrl.slot_eid = {}
				end
				-- anim_ctrl.slot_eid[e.name] = e.eid
			end
		end
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
