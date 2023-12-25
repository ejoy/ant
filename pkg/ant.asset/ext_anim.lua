local datalist  = require "datalist"
local ozz = require "ozz"
local aio = import_package "ant.io"
local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mc, mu = mathpkg.constant, mathpkg.util

local TYPE_LINEAR <const>	= 1
local TYPE_REBOUND <const>	= 2
local TYPE_SHAKE <const>	= 3

local TWEEN_SAMPLE <const>	= 16

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

local function tween_push_anim_key(raw_anim, ske, sample_ratio, joint_name, clip, time, duration, to_pos, to_rot, poseMat, reverse, sum)
	if clip.tween == mu.TWEEN_LINEAR and math.abs(to_rot[1]) < 180 and math.abs(to_rot[2]) < 180 and math.abs(to_rot[3]) < 180 then
		return
	end
	local frametime = 1.0 / sample_ratio
	duration = duration - 2 * frametime --skip the first/last frame
	if duration < frametime then
		return
	end
	local start_rot = sum and sum.rot or {0, 0, 0}
	local start_pos = sum and sum.pos or mc.ZERO
	local tween_step = 1.0 / TWEEN_SAMPLE
	for j = 1, TWEEN_SAMPLE - 1 do
		local rj = reverse and (TWEEN_SAMPLE - j) or j
		local tween_ratio = mu.tween[clip.tween](rj * tween_step)
		local target_pos = math3d.mul(Dir[clip.direction], to_pos * tween_ratio)
		local tween_local_mat = math3d.matrix{
			s = 1,
			r = math3d.quaternion{math.rad(start_rot[1] + to_rot[1] * tween_ratio),
				math.rad(start_rot[2] + to_rot[2] * tween_ratio),
				math.rad(start_rot[3] + to_rot[3] * tween_ratio)},
			t = math3d.add(start_pos, target_pos)
		}
		local tween_to_s, tween_to_r, tween_to_t = math3d.srt(math3d.mul(poseMat, tween_local_mat))
		raw_anim:push_prekey(ske, joint_name, time + j * tween_step * duration, tween_to_s, tween_to_r, tween_to_t)
	end
end

local function push_anim_key(raw_anim, ske, sample_ratio, joint_name, clips, inherit)
	local frame_to_time = 1.0 / sample_ratio
	local poseMat = ske:joint(ske:joint_index(joint_name))
	local localMat = math3d.matrix{s = 1, r = mc.IDENTITY_QUAT, t = mc.ZERO}
	local from_s, from_r, from_t = math3d.srt(math3d.mul(poseMat, localMat))
	local sum = {pos = mc.ZERO, rot = {0, 0, 0}}
	if not clips or #clips < 1 then
		raw_anim:push_prekey(ske, joint_name, 0, from_s, from_r, from_t)
	else
		for _, clip in ipairs(clips) do
			if clip.range[1] >= 0 and clip.range[2] >= 0 then
				local duration = clip.range[2] - clip.range[1] + 1
				local subdiv = clip.repeat_count
				if clip.type == TYPE_REBOUND then
					subdiv = 2 * subdiv
				elseif clip.type == TYPE_SHAKE then
					subdiv = 4 * subdiv
				end
				local step = (duration / subdiv) * frame_to_time
				local start_time = clip.range[1] * frame_to_time
				if duration < subdiv or step <= frame_to_time then
					raw_anim:push_prekey(ske, joint_name, start_time, from_s, from_r, from_t)
					goto continue
				end
				local to_rot = {0,clip.amplitude_rot,0}
				if clip.rot_axis == DIR_X then
					to_rot = {clip.amplitude_rot,0,0}
				elseif clip.rot_axis == DIR_Z then
					to_rot = {0,0,clip.amplitude_rot}
				end
				
				local target_pos = math3d.mul(Dir[clip.direction], clip.amplitude_pos)
				local target_rot = {to_rot[1], to_rot[2], to_rot[3]}
				if inherit then
					target_pos = math3d.add(sum.pos, target_pos)
					target_rot[1] = sum.rot[1] + target_rot[1]
					target_rot[2] = sum.rot[2] + target_rot[2]
					target_rot[3] = sum.rot[3] + target_rot[3]
					from_s, from_r, from_t = math3d.srt(math3d.mul(poseMat, math3d.matrix{s = 1, r = math3d.quaternion{math.rad(sum.rot[1]), math.rad(sum.rot[2]), math.rad(sum.rot[3])}, t = sum.pos}))
				end
				
				localMat = math3d.matrix{s = 1, r = math3d.quaternion{math.rad(target_rot[1]), math.rad(target_rot[2]), math.rad(target_rot[3])}, t = target_pos}
				local to_s, to_r, to_t = math3d.srt(math3d.mul(poseMat, localMat))
				
				local time = start_time
				local endtime = clip.range[2] * frame_to_time
				if clip.type == TYPE_LINEAR then
					for i = 1, clip.repeat_count, 1 do
						raw_anim:push_prekey(ske, joint_name, time, from_s, from_r, from_t)
						tween_push_anim_key(raw_anim, ske, sample_ratio, joint_name, clip, time, step, clip.amplitude_pos, to_rot, poseMat, false, inherit and sum)
						time = start_time + i * step - frame_to_time
						raw_anim:push_prekey(ske, joint_name, time, to_s, to_r, to_t)
						time = time + frame_to_time
						if time >= endtime then
							break;
						end
					end
				else
					localMat = math3d.matrix{s = 1, r = math3d.quaternion{math.rad(-target_rot[1]), math.rad(-target_rot[2]), math.rad(-target_rot[3])}, t = math3d.mul(target_pos, math3d.vector(-1,-1,-1))}
					local to_s2, to_r2, to_t2 = math3d.srt(math3d.mul(poseMat, localMat))
					raw_anim:push_prekey(ske, joint_name, time, from_s, from_r, from_t)
					for i = 1, clip.repeat_count, 1 do
						tween_push_anim_key(raw_anim, ske, sample_ratio, joint_name, clip, time, step, clip.amplitude_pos, to_rot, poseMat, false, inherit and sum)
						time = time + step
						raw_anim:push_prekey(ske, joint_name, time, to_s, to_r, to_t)
						tween_push_anim_key(raw_anim, ske, sample_ratio, joint_name, clip, time, step, clip.amplitude_pos, to_rot, poseMat, true, inherit and sum)
						if clip.type == TYPE_REBOUND then
							time = (i == clip.repeat_count) and (clip.range[2] * frame_to_time) or (time + step)
							raw_anim:push_prekey(ske, joint_name, time, from_s, from_r, from_t)
						elseif clip.type == TYPE_SHAKE then
							time = time + step
							tween_push_anim_key(raw_anim, ske, sample_ratio, joint_name, clip, time, step, -clip.amplitude_pos, {-to_rot[1], -to_rot[2], -to_rot[3]}, poseMat, false, inherit and sum)
							time = time + step
							raw_anim:push_prekey(ske, joint_name, time, to_s2, to_r2, to_t2)
							tween_push_anim_key(raw_anim, ske, sample_ratio, joint_name, clip, time, step, -clip.amplitude_pos, {-to_rot[1], -to_rot[2], -to_rot[3]}, poseMat, true, inherit and sum)
							time = time + step
						end
						if time >= endtime then
							break;
						end
					end
					if clip.type == TYPE_SHAKE then
						raw_anim:push_prekey(ske, joint_name, clip.range[2] * frame_to_time, from_s, from_r, from_t)
					end
				end
				if inherit then
					sum = {pos = target_pos, rot = target_rot}
				end
			end
			::continue::
		end
	end
end

local function absolute_path(path, base)
	if path:sub(1,1) == "/" then
		return path
	end
	return base:match "^(.-)[^/|]*$" .. (path:match "^%./(.+)$" or path)
end

return {
	loader = function (filename)
		local anim_list = datalist.parse(aio.readall(filename))
		local ske_anim
		for _, anim in ipairs(anim_list) do
			if anim.type == "ske" then
				ske_anim = anim
				break
			end
		end
		local ske = ozz.load(aio.readall(absolute_path(ske_anim.skeleton, filename)))
		local raw_animation = ozz.RawAnimation()
		local joint_anims = ske_anim.target_anims
		local sample_ratio = ske_anim.sample_ratio
		local flags = {}
		raw_animation:setup(ske, ske_anim.duration)
		for _, anim in ipairs(joint_anims) do
			flags[ske:joint_index(anim.target_name)] = true
			raw_animation:clear_prekey(ske, anim.target_name)
			push_anim_key(raw_animation, ske, sample_ratio, anim.target_name, anim.clips, anim.inherit and anim.inherit[3])
		end
		local ske_count = ske:num_joints()
		for i = 1, ske_count do
			if not flags[i] then
				local joint_name = ske:joint_name(i)
				raw_animation:clear_prekey(ske, joint_name)
				push_anim_key(raw_animation, ske, sample_ratio, joint_name)
			end
		end
		return raw_animation:build()
	end,
	unloader = function (res)
	end
}
