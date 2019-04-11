local ecs = ...
local world = ecs.world

local asset = import_package "ant.asset"
local timer = import_package "ant.timer"
local animodule = require "hierarchy.animation"

local animation_content = ecs.component "animation_content"		
	.ref_path "respath" ()
	.name "string"
	.scale "real" (1)	
	.looptimes "int" (0)	

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
		self.handle = asset.load(self.ref_path).handle
	end	
	self.start_counter = 0
	self.ratio = 0
	return self
end

ecs.component "aniref"
	.idx "int"	-- TODO: need use name to referent which animation
	.weight "real"

ecs.component "pose"
	.anirefs "aniref[]"
	.name "string"

ecs.component "pose_state"
	.pose "pose"

local animation = ecs.component "animation"  { depend = "skeleton" }
	.pose_state "pose_state"
	.anilist "animation_content[]"
	.blendtype "string" ("blend")

function animation:postinit(e)
	local ske = e.skeleton
	local numjoints = #ske.assetinfo.handle
	self.aniresult = animodule.new_bind_pose_result(numjoints)
	for _, ani in ipairs(self.anilist) do			
		ani.sampling_cache = animodule.new_sampling_cache(numjoints)
	end
end

ecs.component_alias("skeleton", "resource")

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

-- local function update_transform_from_animation(aniresult, ske, e)
-- 	local rootidx = 1
-- 	assert(ske:isroot(rootidx))
-- 	local trans = aniresult:joint(rootidx)
-- 	local s, r, t = ms(ms:matrix(trans), "~PPP")
-- 	e.transform.t(t)
-- end

function anisystem:update()	
	local current_counter = timer.current_counter

	for _, eid in world:each("animation") do
		local e = world[eid]
		local skecomp = assert(e.skeleton)

		local ske = assert(skecomp.assetinfo).handle
		local anicomp = assert(e.animation)

		local fix_root = false
		local ikcomp = e.ik
		if ikcomp and ikcomp.enable then
			local mat = ms:srtmat(e.transform)
			local t = deep_copy(ikcomp)
			t.target = ms(assert(t.target), "m")
			t.pole_vector = ms(assert(t.pole_vector), "m")
			t.mid_axis = ms(assert(t.mid_axis), "m")

			ik_module.do_ik(mat, ske, t, anicomp.aniresult, fix_root)
		else
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
				ani_module.transform(ske, finalbindpose, anicomp.aniresult, fix_root)
			else
				if srcanilist then
					ani_module.motion(ske, srcanilist, anicomp.blendtype, anicomp.aniresult, nil, fix_root)
				end
			end
		end

		-- if not fix_root then
		-- 	update_transform_from_animation(anicomp.aniresult, ske, e)
		-- end
	end
end

local mathadapter_util = import_package "ant.math.adapter"
local math3d_adapter = require "math3d.adapter"
mathadapter_util.bind("animation", function ()
	ik_module.do_ik = math3d_adapter.matrix(ms, ik_module.do_ik, 1)	
end)



-- local post_ani_sys = ecs.system "post_animation_system"
-- post_ani_sys.depend "animation"
-- post_ani_sys.dependby
-- function post_ani_sys:update()
-- 	for _, eid in 
-- end
