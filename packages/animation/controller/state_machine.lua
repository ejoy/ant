local ecs = ...
local world = ecs.world
local w = world.w
local timer = ecs.import.interface "ant.timer|itimer"
local fs 	= require "filesystem"
local lfs	= require "filesystem.local"
local datalist  = require "datalist"

local function get_transmit_merge(e, tt_duration)
	local timepassed = 0
	return function (deltatime)
		timepassed = timepassed + deltatime
		local current_pose = e._animation._current
		if timepassed > tt_duration then
			e._animation._current = current_pose[#current_pose]
			return true
		end
		local scale = math.max(0, math.min(1, timepassed / tt_duration))
		for i = 1, #current_pose-1 do
			current_pose[i].weight = current_pose[i].init_weight * (1 - scale)
		end
		current_pose[#current_pose].weight = scale
		return false
	end
end

local function current_animation(current)
	if current.type == 'blend' then
		return current[#current].animation
	else
		return current.animation
	end
end

local function play_animation(e, name, duration)
	local current_ani = current_animation(e._animation._current)
	if current_ani and current_ani.name == name then
		return
	end
	local current_pose = e._animation._current
	if current_pose.type == "blend" then
		for i = 1, #current_pose do
			current_pose[i].init_weight = current_pose[i].weight
		end
		local ani = e.animation[name]
		current_pose[#current_pose+1] = {
			animation = ani,
			weight = 0,
            ratio = 0,
		}
	elseif current_pose.animation then
		e._animation._current = {
			type = "blend",
			{
				animation = current_pose.animation,
				event_state = {
					next_index = 1,
					keyframe_events = current_pose.event_state
				},
				clip_state = { current = {clip_index = 1}, clips = e._animation.anim_clips and e._animation.anim_clips[name] or {}},
				weight = 1,
				init_weight = 1,
				ratio = current_pose.ratio,
			},
			{
				animation = e.animation[name],
				event_state = {
					next_index = 1,
					keyframe_events = e._animation.keyframe_events and e._animation.keyframe_events[name] or {}
				},
				clip_state = { current = {clip_index = 1}, clips = e._animation.anim_clips and e._animation.anim_clips[name] or {}},
				weight = 0,
				init_weight = 0,
				play_state = { ratio = 0.0, previous_ratio = 0.0, speed = 1.0, play = true, loop = true}
			}
		}
	else
		e._animation._current = {
			animation = e.animation[name],
			event_state = {
				next_index = 1,
				keyframe_events = e._animation.keyframe_events and e._animation.keyframe_events[name] or {}
			},
			clip_state = { current = {clip_index = 1}, clips = e._animation.anim_clips and e._animation.anim_clips[name] or {}},
			play_state = { ratio = 0.0, previous_ratio = 0.0, speed = 1.0, play = true, loop = true}
		}
		return
	end
	e.state_machine.transmit_merge = get_transmit_merge(e, duration * 1000.)
end

local function set_state(e, name, time)
	local sm = e.state_machine
	local info = sm.nodes[name]
	if info.execute then
		play_animation(e, info:execute(), time)
	else
		play_animation(e, name, time)
	end
	sm.current = name
end

-- local sm = ecs.component "state_machine"

-- function sm:init()
-- 	if self.file then
-- 		assert(fs.loadfile(fs.path(self.file)))(self.nodes)
-- 	end
-- 	return self
-- end

-- local sm_trans = ecs.transform "state_machine_transform"

-- function sm_trans.process_entity(e)
-- 	e._animation._current = {}
-- 	set_state(e, e.state_machine.current, 0)
-- end

local state_machine_sys = ecs.system "state_machine_system"

function state_machine_sys:animation_state()
	local delta = timer.delta()
	--for _, eid in world:each "state_machine" do
	--	local e = world[eid]
	--	if e.state_machine.transmit_merge then
	--		if e.state_machine.transmit_merge(delta) then
	--			e.state_machine.transmit_merge = nil
	--		end
	--	end
	--end
end

local iani = ecs.interface "ianimation"

local EditMode = false
function iani.set_edit_mode(b)
	EditMode = b
end

function iani.set_state(e, name)
	local sm = e.state_machine
	if e.animation and sm and sm.nodes[name] then
		if sm.current == name then
			return
		end
		if not sm.current then
			set_state(e, name, 0)
			return
		end
		local info = sm.nodes[sm.current]
		if info and info.transmits[name] then
			set_state(e, name, info.transmits[name].duration)
			return true
		end
	end
end

local function do_play(e, anim, real_clips, anim_state)
	if not anim_state.init then
		local start_ratio = 0.0
		local realspeed = 1.0
		if real_clips then
			start_ratio = real_clips[1][2].range[1] / anim._handle:duration()
			if not anim_state.manual then
				realspeed = real_clips[1][2].speed
			end
			--io.stdout:write("do_play: start_ratio, realspeed ", tostring(start_ratio), " ", tostring(realspeed), "\n")
		end

		anim_state.init = true
		anim_state.eid = {}
		anim_state.animation = anim
		anim_state.event_state = { next_index = 1, keyframe_events = real_clips and real_clips[1][2].key_event or {} }
		anim_state.clip_state = { current = {clip_index = 1, clips = real_clips}, clips = e._animation.anim_clips or {}}
		anim_state.play_state = { ratio = start_ratio, previous_ratio = start_ratio, speed = realspeed, play = true, loop = anim_state.loop, manual_update = anim_state.manual}
		
		world:pub{"animation", anim_state.name, "play"}
	end
	e._animation._current = anim_state
	anim_state.eid[#anim_state.eid + 1] = e
end

function iani.play(e, anim_state)
	w:sync("animation:in _animation:in", e)
	local anim = e.animation[anim_state.name]
	if not anim then
		print("animation:", anim_state.name, "not exist")
		return false
	end
	do_play(e, anim, nil, anim_state)
	return true
end

local function find_clip_or_group(clips, name, group)
	for _, clip in ipairs(clips) do
		if clip.name == name then
			if group then
				if clip.subclips and #clip.subclips > 0 then
					return clip
				end
			else
				return clip
			end
		end
	end
end

function iani.play_clip(e, anim_state)
	w:sync("animation:in _animation:out", e)
	local real_clips
	local clip = find_clip_or_group(e._animation.anim_clips, anim_state.name)
	if clip then
		real_clips = {{e.animation[clip.anim_name], clip }}
	end
	if not clip or not real_clips then
		print("clip:", anim_state.name, "not exist")
		return false
	end
	do_play(e, real_clips[1][1], real_clips, anim_state);
end

function iani.play_group(e, anim_state)
	w:sync("animation:in _animation:in", e)
	local real_clips
	local group = find_clip_or_group(e._animation.anim_clips, anim_state.name, true)
	if group then
		real_clips = {}
		for _, clip_index in ipairs(group.subclips) do
			local anim_name = e._animation.anim_clips[clip_index].anim_name
			real_clips[#real_clips + 1] = {e.animation[anim_name], e._animation.anim_clips[clip_index]}
		end
	end
	if not group or #real_clips < 1 then
		print("group:", anim_state.name, "not exist")
		return false
	end
	do_play(e, real_clips[1][1], real_clips, anim_state);
end

function iani.get_duration(e)
	w:sync("_animation:in", e)
	return e._animation._current.animation._handle:duration()
end

function iani.get_clip_duration(e, name)
	local clip = find_clip_or_group(e._animation.anim_clips, name)
	if not clip then return 0 end
	return clip.range[2] - clip.range[1]
end

function iani.get_group_duration(e, name)
	local group = find_clip_or_group(e._animation.anim_clips, name, true)
	if not group then return end
	local d = 0.0
	for _, index in ipairs(group.subclips) do
		local range = e._animation.anim_clips[index].range
		d = d + range[2] - range[1]
	end
	return d
end

function iani.step(task, s_delta, absolute)
	local play_state = task.play_state
	local playspeed = play_state.manual_update and 1.0 or play_state.speed
	--io.stdout:write("step ", tostring(s_delta), " ", tostring(playspeed), "\n")
	local adjust_delta = play_state.play and s_delta * playspeed or s_delta
	local next_time = absolute and adjust_delta or (play_state.ratio * task.animation._handle:duration() + adjust_delta)
	local duration = task.animation._handle:duration()
	local clip_state = task.clip_state.current
	local clips = clip_state.clips
	if clips then
		local index = clip_state.clip_index
		if next_time > clips[index][2].range[2] then
			local excess = next_time - clips[index][2].range[2]
			if index >= #clips then
				if not play_state.loop then
					play_state.ratio = clips[#clips][2].range[2] / duration
					play_state.play = false
					return
				end
				index = 1
			else
				index = index + 1
			end
			clip_state.clip_index = index
			if task.animation ~= clips[index][1] then
				task.animation = clips[index][1]
			end
			play_state.ratio = (clips[index][2].range[1] + excess) / task.animation._handle:duration()
			
			task.event_state.keyframe_events = clips[index][2].key_event
			play_state.speed = clips[index][2].speed
		else
			play_state.ratio = next_time / duration
		end
		return
	end
	if next_time > duration then
		if not play_state.loop then
			play_state.ratio = 1.0
			play_state.play = false
			world:pub{"animation", task.name, "stop"}
		else
			play_state.ratio = (next_time - duration) / duration
		end
	else
		play_state.ratio = next_time / duration
	end
end

local function get_e(e)
	if not e._animation then
		w:sync("_animation:in", e)
	end
	return e
end

function iani.set_time(e, second)
	if not e then return end
	local e = get_e(e)
	iani.step(e._animation._current, second, true)
	-- effect
	local current_time = iani.get_time(e);
	local all_events = e._animation._current.event_state.keyframe_events
	if all_events then
		for _, events in ipairs(all_events) do
			for _, ev in ipairs(events.event_list) do
				if ev.event_type == "Effect" then
					if ev.effect then
						world:prefab_event(ev.effect, "time", "effect", current_time - events.time, false)
					end
				end
			end
		end
	end
end

function iani.stop_effect(e)
	if not e then return end
	local e = get_e(e)
	local all_events = e._animation._current.event_state.keyframe_events
	if all_events then
		for _, events in ipairs(all_events) do
			for _, ev in ipairs(events.event_list) do
				if ev.event_type == "Effect" then
					if ev.effect then
						world:prefab_event(ev.effect, "stop", "effect")
					end
				end
			end
		end
	end
end

function iani.set_clip_time(e, second)
	if not e then return end
	local e = get_e(e)
	local range = e._animation._current.clip_state.current.clips[1][2].range
	local duration = range[2] - range[1]
	if second > duration then
		if task.play_state.loop then
			second = math.fmod(second, duration)
		else
			task.play_state.ratio = clips[index][2].range[2] / task.animation._handle:duration()
			return
		end
	end
	task.play_state.ratio = (second + clips[index][2].range[1]) / task.animation._handle:duration()
end

function iani.set_group_time(e, second)
	if not e then return end
	local e = get_e(e)
	local task = e._animation._current
	local clips = task.clip_state.current.clips
	local duration = 0.0
	for _, clip in ipairs(clips) do
		duration = duration + (clip[2].range[2] - clip[2].range[1])
	end
	local reach_end
	local index
	if second > duration then
		if task.play_state.loop then
			second = math.fmod(second, duration)
		else
			index = #clips
			reach_end = true
		end
	end
	if not reach_end then
		for i, clip in ipairs(clips) do
			index = i
			local d = clip[2].range[2] - clip[2].range[1]
			if second < d then
				break;
			else
				second = second - d
			end
		end
	end
	if task.clip_state.current.clip_index ~= index then
		task.clip_state.current.clip_index = index
		if task.animation ~= clips[index][1] then
			task.animation = clips[index][1]
		end
	end
	if reach_end then
		task.play_state.ratio = clips[index][2].range[2] / task.animation._handle:duration()
	else
		task.play_state.ratio = (second + clips[index][2].range[1]) / task.animation._handle:duration()
	end
end

function iani.get_time(e)
	if not e then return 0 end
	local e = get_e(e)
	return e._animation._current.play_state.ratio * e._animation._current.animation._handle:duration()
end

function iani.set_speed(e, speed)
	if not e then return end
	local e = get_e(e)
	e._animation._current.play_state.speed = speed
end

function iani.set_loop(e, loop)
	if not e then return end
	local e = get_e(e)
	e._animation._current.play_state.loop = loop
end

function iani.pause(e, pause)
	if not e then return end
	local e = get_e(e)
	e._animation._current.play_state.play = not pause
end

function iani.is_playing(e)
	if not e then return end
	local e = get_e(e)
	return e._animation._current.play_state.play
end

function iani.get_collider(e, anim, time)
	local events = e._animation.keyframe_events[anim]
	if not events then return end
	local colliders
	for _, event in ipairs(events.event) do
		if math.abs(time - event.time) < 0.0001 then
			colliders = {}
			for _, ev in ipairs(event.event_list) do
				if ev.event_type == "Collision" then
					colliders[#colliders + 1] = ev.collision
				end
			end
			break
		end
	end
	return colliders
end

local function do_set_clips(e, clips)
	if not e._animation then
		world.w:sync("_animation:in", e)
	end
	for _, clip in ipairs(e._animation.anim_clips) do 
		if clip.key_event then
			for _, ke in ipairs(clip.key_event) do
				if ke.event_list then
					for _, ev in ipairs(ke.event_list) do
						if ev.event_type == "Effect" and ev.effect then
							world:prefab_event(ev.effect, "remove", "*")
							ev.effect = nil
						end
					end
				end
			end
		end
	end
	e._animation.anim_clips = clips
end

function iani.set_clips(e, clips)
	if type(clips) == "table" then
		do_set_clips(e, clips)
	elseif type(clips) == "string" then
		local path = fs.path(clips):localpath()
		local f = assert(lfs.open(path))
		local data = f:read "a"
		f:close()
		do_set_clips(e, datalist.parse(data))
	end
end

function iani.get_clips(e)
	return e._animation.anim_clips
end

function iani.set_value(e, name, key, value)
	local sm = e.state_machine
	if not sm or not sm.nodes then
		return
	end
	local node = sm.nodes[name]
	if not node then
		return
	end
	node[key] = value
	if sm.current == name then
		set_state(e, name, 0)
	end
end
