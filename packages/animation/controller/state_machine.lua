local ecs = ...
local world = ecs.world
local w = world.w
local iefk	= ecs.import.interface "ant.efk|iefk"
local fs 	= require "filesystem"
local lfs	= require "filesystem.local"
local datalist  = require "datalist"
local animodule = require "hierarchy".animation
local iani 	= ecs.interface "ianimation"
local math3d = require "math3d"
local mathpkg	= import_package "ant.math"
local mc, mu	= mathpkg.constant, mathpkg.util
local EditMode = false
function iani.set_edit_mode(b)
	EditMode = b
end

local TYPE_LINEAR <const>	= 1
local TYPE_REBOUND <const>	= 2
local TYPE_SHAKE <const>	= 3

local TWEEN_SAMPLE <const> 			= 15

local DIR_X <const> 	= 1
local DIR_Y <const> 	= 2
local DIR_Z <const> 	= 3
local DIR_XY <const>	= 4
local DIR_YZ <const>	= 5
local DIR_XZ <const> 	= 6
local DIR_XYZ <const> 	= 7

local Dir = {
    math3d.ref(math3d.vector{1,0,0}),
    math3d.ref(math3d.vector{0,1,0}),
    math3d.ref(math3d.vector{0,0,1}),
    math3d.ref(math3d.normalize(math3d.vector{1,1,0})),
    math3d.ref(math3d.normalize(math3d.vector{0,1,1})),
    math3d.ref(math3d.normalize(math3d.vector{1,0,1})),
    math3d.ref(math3d.normalize(math3d.vector{1,1,1})),
}

function iani.build_animation(ske, raw_animation, joint_anims, sample_ratio)
	local function tween_push_anim_key(raw_anim, joint_name, clip, time, duration, to_pos, to_rot, poseMat, reverse)
		if clip.tween == mu.TWEEN_LINEAR then
			return
		end
        local tween_step = 1.0 / TWEEN_SAMPLE
        for j = 1, TWEEN_SAMPLE - 1 do
			local rj = reverse and (TWEEN_SAMPLE - j) or j
            local tween_ratio = mu.tween[clip.tween](rj * tween_step)
            local tween_local_mat = math3d.matrix{
                s = 1,
                r = math3d.quaternion{math.rad(to_rot[1] * tween_ratio), math.rad(to_rot[2] * tween_ratio), math.rad(to_rot[3] * tween_ratio)},
                t = math3d.mul(Dir[clip.direction], to_pos * tween_ratio)
            }
            local tween_to_s, tween_to_r, tween_to_t = math3d.srt(math3d.mul(poseMat, tween_local_mat))
            raw_anim:push_prekey(joint_name, time + j * tween_step * duration, tween_to_s, tween_to_r, tween_to_t)
        end
    end
    local function push_anim_key(raw_anim, joint_name, clips)
		local frame_to_time = 1.0 / sample_ratio
        local poseMat = ske:joint(ske:joint_index(joint_name))
		local localMat = math3d.matrix{s = 1, r = mc.IDENTITY_QUAT, t = mc.ZERO}
        local from_s, from_r, from_t = math3d.srt(math3d.mul(poseMat, localMat))
		if not clips then
			raw_anim:push_prekey(joint_name, 0, from_s, from_r, from_t)
		else
			for _, clip in ipairs(clips) do
				if clip.range[1] >= 0 and clip.range[2] >= 0 then
					local duration = clip.range[2] - clip.range[1]
					local subdiv = clip.repeat_count
					if clip.type == TYPE_REBOUND then
						subdiv = 2 * subdiv
					elseif clip.type == TYPE_SHAKE then
						subdiv = 4 * subdiv
					end
					local step = (duration / subdiv) * frame_to_time
					local start_time = clip.range[1] * frame_to_time
					local to_rot = {0,clip.amplitude_rot,0}
					if clip.rot_axis == DIR_X then
						to_rot = {clip.amplitude_rot,0,0}
					elseif clip.rot_axis == DIR_Z then
						to_rot = {0,0,clip.amplitude_rot}
					end
					localMat = math3d.matrix{s = 1, r = math3d.quaternion{math.rad(to_rot[1]), math.rad(to_rot[2]), math.rad(to_rot[3])}, t = math3d.mul(Dir[clip.direction], clip.amplitude_pos)}
					local to_s, to_r, to_t = math3d.srt(math3d.mul(poseMat, localMat))
					local time = start_time
					if clip.type == TYPE_LINEAR then
						for i = 1, clip.repeat_count, 1 do
							raw_anim:push_prekey(joint_name, time, from_s, from_r, from_t)
							tween_push_anim_key(raw_anim, joint_name, clip, time, step, clip.amplitude_pos, to_rot, poseMat)
							time = time + step
							raw_anim:push_prekey(joint_name,time, to_s, to_r, to_t)
							time = time + frame_to_time
						end
					else
						localMat = math3d.matrix{s = 1, r = math3d.quaternion{math.rad(-to_rot[1]), math.rad(-to_rot[2]), math.rad(-to_rot[3])}, t = math3d.mul(Dir[clip.direction], -clip.amplitude_pos)}
						local to_s2, to_r2, to_t2 = math3d.srt(math3d.mul(poseMat, localMat))
						raw_anim:push_prekey(joint_name, time, from_s, from_r, from_t)
						for i = 1, clip.repeat_count, 1 do
							tween_push_anim_key(raw_anim, joint_name, clip, time, step, clip.amplitude_pos, to_rot, poseMat)
							time = time + step
							raw_anim:push_prekey(joint_name, time, to_s, to_r, to_t)
							tween_push_anim_key(raw_anim, joint_name, clip, time, step, clip.amplitude_pos, to_rot, poseMat, true)
							if clip.type == TYPE_REBOUND then
								time = (i == clip.repeat_count) and (clip.range[2] * frame_to_time) or (time + step)
								raw_anim:push_prekey(joint_name, time, from_s, from_r, from_t)
							elseif clip.type == TYPE_SHAKE then
								time = time + step
								tween_push_anim_key(raw_anim, joint_name, clip, time, step, -clip.amplitude_pos, {-to_rot[1], -to_rot[2], -to_rot[3]}, poseMat)
								time = time + step
								raw_anim:push_prekey(joint_name, time, to_s2, to_r2, to_t2)
								tween_push_anim_key(raw_anim, joint_name, clip, time, step, -clip.amplitude_pos, {-to_rot[1], -to_rot[2], -to_rot[3]}, poseMat, true)
								time = time + step
							end
						end
						if clip.type == TYPE_SHAKE then
							raw_anim:push_prekey(joint_name, clip.range[2] * frame_to_time, from_s, from_r, from_t)
						end
					end
				end
			end
		end
    end
	
	local flags = {}
    for _, anim in ipairs(joint_anims) do
		flags[ske:joint_index(anim.target_name)] = true
        raw_animation:clear_prekey(anim.target_name)
        push_anim_key(raw_animation, anim.target_name, anim.clips)
    end
	local ske_count = #ske
	for i=1, ske_count do
		if not flags[i] then
			local joint_name = ske:joint_name(i)
			raw_animation:clear_prekey(joint_name)
        	push_anim_key(raw_animation, joint_name)
		end
    end
    return raw_animation:build()
end
local assetmgr 		= import_package "ant.asset"

local function get_anim_e(eid)
	if type(eid) == "table" then
		local entitys = eid.tag["*"]
		for _, eid in ipairs(entitys) do
			local e = w:entity(eid, "anim_ctrl?in")
			if e.anim_ctrl then
				w:extend(e, "anim_ctrl:in animation:in skeleton:in")
				return e
			end
		end
		if eid.tag["*"] then
			return w:entity(eid.tag["*"][2], "anim_ctrl:in animation:in skeleton:in")
		end
	else
		return w:entity(eid, "anim_ctrl:in animation:in skeleton:in")
	end
end

function iani.create(filename)
	return ecs.create_instance(filename)
end

function iani.play(eid, anim_state)
	local e <close> = get_anim_e(eid)
	local anim_name = anim_state.name
	local anim = e.animation[anim_name]
	if not anim then
		local ext = anim_name:match "[^.]*$"
		if ext == "anim" then
			local path = fs.path(anim_name):localpath()
			local f = assert(fs.open(path))
			local data = f:read "a"
			f:close()
			local anim_data = datalist.parse(data)
			local duration = anim_data.duration
			anim = {
				_duration = duration,
				_sampling_context = animodule.new_sampling_context(1)
			}
			local ske = e.skeleton._handle
			local raw_animation = animodule.new_raw_animation()
			raw_animation:setup(ske, duration)
			anim._handle = iani.build_animation(ske, raw_animation, anim_data.joint_anims, anim_data.sample_ratio)
		else
			print("animation:", anim_name, "not exist")
			return
		end
		e.animation[anim_name] = anim
	end
	e.anim_ctrl.name = anim_name
	e.anim_ctrl.owner = anim_state.owner
	e.anim_ctrl.animation = anim
	e.anim_ctrl.play_state = { ratio = 0.0, previous_ratio = 0.0, play = true, speed = anim_state.speed or 1.0, loop = anim_state.loop, manual_update = anim_state.manual, forwards = anim_state.forwards}
	local all_events = e.anim_ctrl.event_state.keyframe_events
	if all_events then
		for _, events in ipairs(all_events) do
			for _, ev in ipairs(events.event_list) do
				if ev.event_type == "Effect" then
					if ev.effect then
						local e <close> = w:entity(ev.effect)
						iefk.stop(e)
						--TODO: clear keyevent effct
						--w:remove(ev.effect)
					end
				end
			end
		end	
	end
	e.anim_ctrl.event_state = { next_index = 1, keyframe_events = e.anim_ctrl.keyframe_events[anim_name] }
	world:pub{"animation", anim_name, "play", anim_state.owner}
end

function iani.get_duration(eid, anim_name)
	local e <close> = get_anim_e(eid)
	if not anim_name then
		return e.anim_ctrl.animation._handle:duration()
	else
		return e.animation[anim_name]._handle:duration()
	end
end

function iani.step(anim_e, s_delta, absolute)
	local ctrl = anim_e.anim_ctrl
	local ani = ctrl.animation
	if not ani then
		return
	end
	local play_state = ctrl.play_state
	local playspeed = play_state.manual_update and 1.0 or play_state.speed
	local adjust_delta = play_state.play and s_delta * playspeed or s_delta
	local duration = ani._handle:duration()
	local next_time = absolute and adjust_delta or (play_state.ratio * duration + adjust_delta)
	if next_time > duration then
		if not play_state.loop then
			play_state.ratio = play_state.forwards and 1.0 or 0.0
			play_state.play = false
			world:pub{"animation", ctrl.name, "stop", ctrl.owner}
		else
			play_state.ratio = (next_time - duration) / duration
		end
	else
		play_state.ratio = next_time / duration
	end
	local pr = ctrl.pose_result
	pr:setup(anim_e.skeleton._handle)
	pr:do_sample(ani._sampling_context, ani._handle, play_state.ratio, ctrl.weight)
	ctrl.dirty = true
end

function iani.set_time(eid, second)
	if not eid then return end
	local e <close> = get_anim_e(eid)
	iani.step(e, second, true)
	-- effect
	local current_time = iani.get_time(eid);
	local all_events = e.anim_ctrl.event_state.keyframe_events
	if all_events then
		for _, events in ipairs(all_events) do
			for _, ev in ipairs(events.event_list) do
				if ev.event_type == "Effect" then
					if ev.effect then
						local e <close> = w:entity(ev.effect)
						iefk.set_time(e, (current_time - events.time) * 60)
					end
				end
			end
		end
	end
end

function iani.stop_effect(eid)
	if not eid then return end
	local e <close> = get_anim_e(eid)
	local all_events = e.anim_ctrl.event_state.keyframe_events
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

function iani.get_time(eid)
	if not eid then return 0 end
	local e <close> = get_anim_e(eid)
	if not e.anim_ctrl.animation then return 0 end
	return e.anim_ctrl.play_state.ratio * e.anim_ctrl.animation._handle:duration()
end

function iani.set_speed(eid, speed)
	if not eid then return end
	local e <close> = get_anim_e(eid)
	e.anim_ctrl.play_state.speed = speed
end

function iani.set_loop(eid, loop)
	if not eid then return end
	local e <close> = get_anim_e(eid)
	e.anim_ctrl.play_state.loop = loop
end

function iani.pause(eid, pause)
	if not eid then return end
	local e <close> = get_anim_e(eid)
	e.anim_ctrl.play_state.play = not pause
end

function iani.is_playing(eid)
	if not eid then return end
	local e <close> = get_anim_e(eid)
	return e.anim_ctrl.play_state.play
end

function iani.get_collider(e, anim, time)
	local events = e.anim_ctrl.keyframe_events[anim]
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

function iani.set_pose_to_prefab(instance, pose)
	local entitys = instance.tag["*"]
	for _, eid in ipairs(entitys) do
		local e <close> = w:entity(eid, "meshskin?in slot?in animation?in")
		if e.meshskin then
			w:extend(e, "skeleton:in")
			pose.skeleton = e.skeleton
			e.meshskin.pose = pose
		elseif e.slot then
			e.slot.pose = pose
		elseif e.animation then
			w:extend(e, "anim_ctrl:in skeleton:in")
			pose.pose_result = e.anim_ctrl.pose_result
			pose.skeleton = e.skeleton
		end
	end
end

local anim_pose_mgr = {}

function iani.create_pose()
	local pose = {}
	anim_pose_mgr[#anim_pose_mgr + 1] = pose
	return pose
end

function iani.release_pose(pose)
	if pose.pose then
		pose.pose = nil
	end
end