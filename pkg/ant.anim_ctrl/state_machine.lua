local ecs = ...
local world = ecs.world
local w = world.w
local iefk	= ecs.require "ant.efk|efk"
local animation	= ecs.require "ant.animation|animation"
local fs 	= require "filesystem"
local datalist  = require "datalist"
local aio = import_package "ant.io"

local iani = {}

local EditMode = false
function iani.set_edit_mode(b)
	EditMode = b
end

local function get_anim_eid(anim_e)
	if not anim_e then
		return
	end
	if type(anim_e) == "table" then
		local entitys = anim_e.tag["*"]
		for _, eid in ipairs(entitys) do
			local e <close> = world:entity(eid, "anim_ctrl?in")
			if e.anim_ctrl then
				return eid
			end
		end
	else
		local e <close> = world:entity(anim_e, "anim_ctrl?in")
		if e.anim_ctrl then
			return anim_e
		end
	end
end

local function stop_all_effect(all_events, delay)
	if not all_events then
		return
	end
	for _, events in ipairs(all_events) do
		for _, ev in ipairs(events.event_list) do
			if ev.event_type == "Effect" and ev.effect then
				local e <close> = world:entity(ev.effect, "efk:in")
				iefk.stop(e, delay)
			end
		end
	end
end

function iani.create(filename)
	return world:create_instance {
		prefab = filename,
	}
end

function iani.load_events(anim_e, filename)
	if not fs.exists(fs.path(filename)) then
		return
	end
	local events = datalist.parse(aio.readall(filename))
	local anim_eid = get_anim_eid(anim_e)
	if not anim_eid then
		return
	end
	local e <close> = world:entity(anim_eid, "anim_ctrl:in")
	events.filename = filename
	e.anim_ctrl.keyframe_events = events
end

function iani.play(eid, anim_state)
	local anim_eid = get_anim_eid(eid)
	if not anim_eid then
		return
	end
	local e <close> = world:entity(anim_eid, "anim_ctrl:in playing?out")
	local anim_name = anim_state.name
	e.anim_ctrl.name = anim_name
	e.anim_ctrl.animation = anim_name
	e.anim_ctrl.owner = anim_state.owner
	e.anim_ctrl.group = anim_state.group
	e.anim_ctrl.context = anim_state.context
	e.anim_ctrl.play_state = { ratio = 0.0, previous_ratio = 0.0, play = true, speed = anim_state.speed or 1.0, loop = anim_state.loop, manual_update = anim_state.manual, forwards = anim_state.forwards}
	stop_all_effect(e.anim_ctrl.event_state.keyframe_events)
	e.anim_ctrl.event_state = { next_index = 1, keyframe_events = e.anim_ctrl.keyframe_events[anim_name] }
	e.playing = true
	world:pub{"animation", anim_name, "play", anim_state.owner}
end

function iani.get_duration(eid, name)
	local anim_eid = get_anim_eid(eid)
	if not anim_eid then
		return
	end
	local e <close> = world:entity(anim_eid, "anim_ctrl:in")
	if not name then
		name = e.anim_ctrl.animation
	end
	return animation.get_duration(e, name)
end

function iani.step(anim_e, s_delta, absolute)
	local ctrl = anim_e.anim_ctrl
	local name = ctrl.animation
	if not name then
		return
	end
	local duration = animation.get_duration(anim_e, name)
	if not duration then
		return
	end
	local play_state = ctrl.play_state
	local playspeed = play_state.manual_update and 1.0 or play_state.speed
	local adjust_delta = play_state.play and s_delta * playspeed or s_delta
	local next_time = absolute and adjust_delta or (play_state.ratio * duration + adjust_delta)
	if next_time > duration then
		if not play_state.loop then
			play_state.ratio = play_state.forwards and 1.0 or 0.0
			play_state.play = false
			world:pub{"animation", ctrl.name, "stop", ctrl.owner}
		else
			play_state.ratio = (next_time - duration) / duration
		end
		stop_all_effect(ctrl.event_state.keyframe_events, true)
	else
		play_state.ratio = next_time / duration
	end
	w:extend(anim_e, "playing?out")
	ctrl.dirty = true
	anim_e.playing = ctrl.play_state.play
	animation.reset(anim_e)
	animation.set_status(anim_e, name, play_state.ratio, 1)
end

function iani.set_time(eid, second)
	local anim_eid = get_anim_eid(eid)
	if not anim_eid then
		return
	end
	local e <close> = world:entity(anim_eid, "anim_ctrl:in")
	iani.step(e, second, true)
	-- effect
	local current_time = iani.get_time(eid);
	local all_events = e.anim_ctrl.event_state.keyframe_events
	if all_events then
		for _, events in ipairs(all_events) do
			for _, ev in ipairs(events.event_list) do
				if ev.event_type == "Effect" and ev.effect then
					local ee <close> = world:entity(ev.effect, "efk:in")
					iefk.set_time(ee, (current_time - events.time) * 60)
				end
			end
		end
	end
end

function iani.stop_effect(eid)
	local anim_eid = get_anim_eid(eid)
	if not anim_eid then
		return
	end
	local e <close> = world:entity(anim_eid, "anim_ctrl:in")
	stop_all_effect(e.anim_ctrl.event_state.keyframe_events)
end

function iani.get_time(eid)
	local anim_eid = get_anim_eid(eid)
	if not anim_eid then
		return 0
	end
	local e <close> = world:entity(anim_eid, "anim_ctrl:in")
	local name = e.anim_ctrl.animation
	if not name then
		return 0
	end
	local duration = animation.get_duration(e, name)
	if not duration then
		return 0
	end
	return e.anim_ctrl.play_state.ratio * duration
end

function iani.set_speed(eid, speed)
	local anim_eid = get_anim_eid(eid)
	if not anim_eid then
		return
	end
	local e <close> = world:entity(anim_eid, "anim_ctrl:in")
	e.anim_ctrl.play_state.speed = speed
end

function iani.set_loop(eid, loop)
	local anim_eid = get_anim_eid(eid)
	if not anim_eid then
		return
	end
	local e <close> = world:entity(anim_eid, "anim_ctrl:in")
	e.anim_ctrl.play_state.loop = loop
end

function iani.pause(eid, pause)
	local anim_eid = get_anim_eid(eid)
	if not anim_eid then
		return
	end
	local e <close> = world:entity(anim_eid, "anim_ctrl:in playing?out")
	e.playing = not pause
	e.anim_ctrl.play_state.play = not pause
end

function iani.is_playing(eid)
	local anim_eid = get_anim_eid(eid)
	if not anim_eid then
		return
	end
	local e <close> = world:entity(anim_eid, "anim_ctrl:in")
	return e.anim_ctrl.play_state.play
end

return iani
