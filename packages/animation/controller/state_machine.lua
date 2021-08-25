local ecs = ...
local world = ecs.world
local timer = world:interface "ant.timer|itimer"
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
				clip_state = { current = {clip_index = 1}, clips = e.anim_clips and e.anim_clips[name] or {}},
				weight = 1,
				init_weight = 1,
				ratio = current_pose.ratio,
			},
			{
				animation = e.animation[name],
				event_state = {
					next_index = 1,
					keyframe_events = e.keyframe_events and e.keyframe_events[name] or {}
				},
				clip_state = { current = {clip_index = 1}, clips = e.anim_clips and e.anim_clips[name] or {}},
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
				keyframe_events = e.keyframe_events and e.keyframe_events[name] or {}
			},
			clip_state = { current = {clip_index = 1}, clips = e.anim_clips and e.anim_clips[name] or {}},
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
	for _, eid in world:each "state_machine" do
		local e = world[eid]
		if e.state_machine.transmit_merge then
			if e.state_machine.transmit_merge(delta) then
				e.state_machine.transmit_merge = nil
			end
		end
	end
end

local iani = ecs.interface "animation"

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

function get_play_info(eid, name)

end

local function do_play(e, anim, real_clips, isloop, manual)
	local start_ratio = 0.0
	if real_clips then
		start_ratio = real_clips[1][2].range[1] / anim._handle:duration()
	end
	e._animation._current = {
		animation = anim,
		event_state = {
			next_index = 1,
			keyframe_events = real_clips and real_clips[1][2].key_event or {}
		},
		clip_state = { current = {clip_index = 1, clips = real_clips}, clips = e.anim_clips or {}},
		play_state = { ratio = start_ratio, previous_ratio = start_ratio, speed = 1.0, play = true, loop = isloop or false, manual_update = manual}
	}
end

function iani.play(eid, name, loop, manual)
	for e in world.w:select "eid:in animation:in _animation:in anim_clips:in" do
		if e.eid == eid then
			local anim = e.animation[name]
			if not anim then
				print("animation:", name, "not exist")
				return false
			end
			do_play(e, anim, nil, loop, manual)
			return true
		end
	end
	return false
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

function iani.play_clip(eid, name, loop, manual)
	for e in world.w:select "eid:in animation:in _animation:in anim_clips:in" do
		if e.eid == eid then
			local real_clips
			local clip = find_clip_or_group(e.anim_clips, name)
			if clip then
				real_clips = {{e.animation[clip.anim_name], clip }}
			end
			if not clip or not real_clips then
				print("clip:", name, "not exist")
				return false
			end
			do_play(e, real_clips[1][1], real_clips, loop, manual);
		end
	end
end

function iani.play_group(eid, name, loop, manual)
	for e in world.w:select "eid:in animation:in _animation:in anim_clips:in" do
		if e.eid == eid then
			local real_clips
			local group = find_clip_or_group(e.anim_clips, name, true)
			if group then
				real_clips = {}
				for _, clip_index in ipairs(group.subclips) do
					local anim_name = e.anim_clips[clip_index].anim_name
					real_clips[#real_clips + 1] = {e.animation[anim_name], e.anim_clips[clip_index]}
				end
			end
			if not group or #real_clips < 1 then
				print("group:", name, "not exist")
				return false
			end
			do_play(e, real_clips[1][1], real_clips, loop, manual);
		end
	end
end

function iani.get_duration(eid)
	for e in world.w:select "eid:in" do
		if e.eid == eid then
			world.w:sync("_animation:in", e)
			return e._animation._current.animation._handle:duration()
		end
	end
end

function iani.get_clip_duration(eid, name)
	for e in world.w:select "eid:in" do
		if e.eid == eid then
			world.w:sync("anim_clips:in", e)
			local clip = find_clip_or_group(e.anim_clips, name)
			if not clip then return 0 end
			return clip.range[2] - clip.range[1]
		end
	end
	return 0
end

function iani.get_group_duration(eid, name)
	for e in world.w:select "eid:in" do
		if e.eid == eid then
			world.w:sync("anim_clips:in", e)
			local group = find_clip_or_group(e.anim_clips, name, true)
			if not group then return end
			local d = 0.0
			for _, index in ipairs(group.subclips) do
				local range = e.anim_clips[index].range
				d = d + range[2] - range[1]
			end
			return d
		end		
	end
	return 0
end

function iani.step(task, s_delta, absolute)
	local play_state = task.play_state
	local next_time = absolute and s_delta or (play_state.ratio * task.animation._handle:duration() + s_delta) * play_state.speed
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
		else
			play_state.ratio = next_time / duration
		end
		return
	end
	if next_time > duration then
		if not play_state.loop then
			play_state.ratio = 1.0
		else
			play_state.ratio = (next_time - duration) / duration
		end
	else
		play_state.ratio = next_time / duration
	end
end

local function get_e(eid)
	for e in world.w:select "eid:in" do
		if e.eid == eid then
			world.w:sync("_animation:in", e)
			return e
		end
	end
end

function iani.set_time(eid, second)
	local e = get_e(eid)
	if e then
		iani.step(e._animation._current, second, true)
		-- effect
		local current_time = iani.get_time(eid);
		local all_events = e._animation._current.event_state.keyframe_events
		if all_events then
			for _, events in ipairs(all_events) do
				for _, ev in ipairs(events.event_list) do
					if ev.event_type == "Effect" then
						if ev.effect then
							world:prefab_event(ev.effect, "time", "root", current_time - events.time, false)
						end
					end
				end
			end
		end
	end
end

function iani.stop_effect(eid)
	local e = get_e(eid)
	if e then
		local all_events = e._animation._current.event_state.keyframe_events
		if all_events then
			for _, events in ipairs(all_events) do
				for _, ev in ipairs(events.event_list) do
					if ev.event_type == "Effect" then
						if ev.effect then
							world:prefab_event(ev.effect, "stop", "root")
						end
					end
				end
			end
		end
	end
end

function iani.set_clip_time(eid, second)
	local e = get_e(eid)
	if not e then return end
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

function iani.set_group_time(eid, second)
	local e = get_e(eid)
	if not e then return end
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

function iani.get_time(eid)
	local e = get_e(eid)
	if e then
		return e._animation._current.play_state.ratio * e._animation._current.animation._handle:duration()
	end
	return 0
end

function iani.set_speed(eid, speed)
	local e = get_e(eid)
	if e then
		e._animation._current.play_state.speed = speed
	end
end

function iani.set_loop(eid, loop)
	local e = get_e(eid)
	if e then
		e._animation._current.play_state.loop = loop
	end
end

function iani.pause(eid, pause)
	local e = get_e(eid)
	if e then
		e._animation._current.play_state.play = not pause
	end
end

function iani.is_playing(eid)
	local e = get_e(eid)
	if e then
		return e._animation._current.play_state.play
	end
end

local function do_set_event(eid, anim, events)
	for e in world.w:select "eid:in animation:in _animation:in keyframe_events:in" do
		if e.eid == eid then
			e.keyframe_events[anim] = events
			if e._animation._current.animation == e.animation[anim] then
				e._animation._current.event_state.keyframe_events = e.keyframe_events[anim]
			end
		end
	end
end

function iani.get_collider(eid, anim, time)
	for e in world.w:select "eid:in" do
		if e.eid == eid then
			world.w:sync("keyframe_events:in", e)
			local events = e.keyframe_events[anim]
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
	end
end

local function do_set_clips(eid, clips)
	for e in world.w:select "eid:in" do
		if e.eid == eid then
			world.w:sync("anim_clips:in", e)
			for _, clip in ipairs(e.anim_clips) do 
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
			e.anim_clips = clips
			world.w:sync("anim_clips:out", e)
			return
		end
	end
end

function iani.set_clips(eid, clips)
	if type(clips) == "table" then
		do_set_clips(eid, clips)
	elseif type(clips) == "string" then
		local path = fs.path(clips):localpath()
		local f = assert(lfs.open(path))
		local data = f:read "a"
		f:close()
		do_set_clips(eid, datalist.parse(data))
	end
end

function iani.get_clips(eid)
	for e in world.w:select "eid:in anim_clips:in" do
		if e.eid == eid then return e.anim_clips end
	end
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
