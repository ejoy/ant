local ecs   = ...
local world = ecs.world
local w     = world.w
local mathpkg	= import_package "ant.math"
local mu	= mathpkg.util

local ika = {}

function ika.create(frames)
    return world:create_entity{
        policy = {
            "ant.anim_ctrl|keyframe",
        },
        data = {
            keyframe = {
				frames = frames or {},
				play_state = {}
            },
        }
    }
end

function ika.add(e, time_ms, value, idx)
    local frames = e.keyframe.frames
	idx = idx or #frames+1
	table.insert(frames, idx, {
        value	 	= value,
        time 		= time_ms,	--ms
    })
end

function ika.remove(e, idx)
	w:extend(e, "keyframe:in")
    idx = idx or #e.keyframe.frames
    table.remove(e.keyframe.frames, idx)
end

function ika.clear(e)
	w:extend(e, "keyframe:in")
    e.keyframe.frames = {}
end

function ika.stop(e)
	if not e then
		return
	end
	w:extend(e, "keyframe?in")
	if not e.keyframe then
		return
	end
	local ps = e.keyframe.play_state
	ps.playing = false
end

function ika.set_loop(e, loop)
	if not e then
		return
	end
	w:extend(e, "keyframe?in")
	if not e.keyframe then
		return
	end
	local ps = e.keyframe.play_state
	ps.loop = loop
end

function ika.play(e, desc)
	ika.stop(e)
	-- w:extend(e, "keyframe?in")
	if not e.keyframe then
		return
	end
	local ps = e.keyframe.play_state
	ps.loop = desc.loop
	ps.forwards = desc.forwards
	ps.current_time = 0
	ps.playing = true
end

local ma_sys = ecs.system "keyframe_system"
function ma_sys:component_init()
    -- for e in w:select "INIT keyframe:in" do
    --     e.keyframe.play_state = {
    --         current_time = 0,
    --         target_e = nil,
	-- 		loop = false,
	-- 		playing = false
    --     }
    -- end
end

local timer = ecs.require "ant.timer|timer_system"

local function step_keyframe(e, delta_time, absolute)
	-- w:extend(e, "keyframe:in")
	local kf_anim = e.keyframe
	if not kf_anim.play_state.playing and not absolute then
		return
	end
	local frames = kf_anim.frames
	if #frames < 2 then return end

	local play_state = kf_anim.play_state
	local lerp = function (v0, v1, f)
		if type(v0) == "table" then
			local count = #v0
			local ret = {}
			for i = 1, count do
				ret[#ret + 1] = v0[i] + (v1[i] - v0[i]) * f
			end
			return ret
		else
			return v0 + (v1 - v0) * f
		end
	end
	local function update_value(time)
		if time < frames[1].time then
			return nil, false
		end
		local frame_count = #frames
		for i = 1, frame_count do
			if time < frames[i].time then
				local factor = math.min((time - frames[i-1].time) / (frames[i].time - frames[i-1].time), 1.0)
				if frames[i-1].tween then
					factor = mu.tween[frames[i-1].tween](factor)
				end
				return lerp(frames[i-1].value, frames[i].value, factor), false
			elseif i == frame_count then
				return frames[i].value, true
			end
		end
	end
	play_state.current_time = absolute and delta_time or play_state.current_time + delta_time
	local value, last = update_value(play_state.current_time)
	play_state.current_value = value
	if last then
		if play_state.loop then
			play_state.current_time = 0
		else
			play_state.playing = false
			play_state.current_value = play_state.forwards and frames[#frames].value or frames[1].value
		end
	end
end

function ika.set_time(e, t)
	if not e then
		return
	end
	w:extend(e, "keyframe?in")
	if not e.keyframe then
		return
	end
	step_keyframe(e, t, true)
end

function ika.get_time(e)
	if not e then
		return 0
	end
	w:extend(e, "keyframe?in")
	return e.keyframe and e.keyframe.play_state.current_time or 0
end

function ika.is_playing(e)
	if not e then
		return false
	end
	w:extend(e, "keyframe?in")
	return e.keyframe and e.keyframe.play_state.playing
end

function ma_sys.data_changed()
	local delta_time = timer.delta()
	for e in w:select "keyframe:in" do
		step_keyframe(e, delta_time * 0.001)
	end
end

return ika
