local ecs = ...
local world = ecs.world
local schema = ecs.schema

local asset = import_package "ant.asset"
local timer = import_package "ant.timer"
local animodule = require "hierarchy.animation"

schema:type "animation_content"		
	.ref_path "respath" ()
	.name "string"
	.scale "real" (1)	
	.looptimes "int" (0)

local animation_content = ecs.component "animation_content"

local function calc_ratio(current_counter, ani)
	local handle = assert(ani.handle)
	local duration = handle:duration() * 1000
	local localtime = timer.from_counter(current_counter - ani.start_counter) * ani.scale
	local frametime
	if ani.looptimes > 0 then
		frametime = localtime - duration * ani.looptimes
	else
		frametime = localtime % duration
	end
	
	frametime = math.max(0, math.min(duration, frametime))
	return frametime / duration
end

function animation_content:init()
	if self.ref_path then
		self.handle = asset.load(self.ref_path.package, self.ref_path.filename).handle
	end	
	self.start_counter = 0
	self.ratio = 0
	return self
end

schema:type "aniref"
	.idx "int"	-- TODO: need use name to referent which animation
	.weight "real"

schema:type "pose"
	.anirefs "aniref[]"
	.name "string"

schema:type "pose_state"
	.pose "pose"

schema:type "animation"
	.pose_state "pose_state"
	.anilist "animation_content[]"
	.blendtype "string" ("blend")

schema:typedef("skeleton", "resource")

local anisystem = ecs.system "animation_system"

local ani_module = require "hierarchy.animation"
local ik_module = require "hierarchy.ik"

local ms = import_package "ant.math".stack

local function deep_copy(t)
	local typet = type(t)
	if typet == "table" then
		local tmp = {}
		for k, v in pairs(t) do
			tmp[k] = deep_copy(v)
		end
		return tmp
	end
	return t
end

function anisystem:update()	
	local current_counter = timer.current_counter

	for _, eid in world:each("animation") do
		local e = world[eid]
		local skecomp = assert(e.skeleton)

		local ske = assert(skecomp.assetinfo).handle
		local anicomp = assert(e.animation)

		local ikcomp = e.ik
		if ikcomp and ikcomp.enable then
			local mat = ms({type="srt", s=e.scale, r=e.rotation, t=e.position}, "m")

			local t = deep_copy(ikcomp)
			t.target = ms(assert(t.target), "m")
			t.pole_vector = ms(assert(t.pole_vector), "m")
			t.mid_axis = ms(assert(t.mid_axis), "m")

			ik_module.do_ik(mat, ske, t, anicomp.aniresult)
		else
			-- local anilist = assert(anicomp.anilist)
			-- if #anilist > 0 then
			-- 	for _, a in ipairs(anilist) do
			-- 		assert(a.starttime and a.starttime ~= 0)
			-- 		a.ratio = calc_ratio(timer.current, a)
			-- 	end
			-- 	ani_module.motion(ske, anilist, anicomp.blendtype, anicomp.aniresult)
			-- end

			local pose_state = anicomp.pose_state
			local pose = pose_state.pose
			local transmit = pose_state.transmit

			local anilist = anicomp.anilist
			local function fetch_anilist(pose)				
				local anis = {}
				for _, aniref in ipairs(pose.anirefs) do
					local ani = assert(anilist[aniref.idx])
					ani.ratio = calc_ratio(current_counter, ani)
					ani.weight = aniref.weight
					anis[#anis+1] = ani
				end
				return anis
			end

			local srcanilist = fetch_anilist(pose)
			if transmit then
				local targetanilist = fetch_anilist(transmit.targetpose)
				local srcbindpose = ani_module.new_bind_pose()
				local targetbindpose = ani_module.new_bind_pose()

				ani_module.blend_animations(ske, srcanilist, anicomp.blendtype, srcbindpose)
				ani_module.blend_animations(ske, targetanilist, anicomp.blendtype, targetbindpose)

				local finalbindpose = ani_module.new_bind_pose()
				ani_module.blend_bind_poses(ske, {
					{pose=srcbindpose, weight=assert(transmit.source_weight)}, 
					{pose=targetbindpose, weight=assert(transmit.target_weight)}
				}, anicomp.blendtype, finalbindpose)
				ani_module.transform(ske, finalbindpose, anicomp.aniresult)
			else
				if srcanilist then
					ani_module.motion(ske, srcanilist, anicomp.blendtype, anicomp.aniresult)
				end
			end
			
		end		
	end
end

function anisystem:post_init()
	for eid in world:each_new("animation") do
		local e = world[eid]
		local ske = assert(e.skeleton)
		local anicomp = e.animation
		local numjoints = #ske.assetinfo.handle
		anicomp.aniresult = animodule.new_ani_result(numjoints)
		
		for _, ani in ipairs(anicomp.anilist) do			
			ani.sampling_cache = animodule.new_sampling_cache(numjoints)
		end
	end
end