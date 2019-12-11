local ecs = ...
local world = ecs.world

local asset = import_package "ant.asset".mgr
local timer = import_package "ant.timer"
local animodule = require "hierarchy.animation"

local animation_content = ecs.component "animation_content"
	.ref_path "respath"
	.scale "real" (1)
	.looptimes "int" (0)

function animation_content:init()
	asset.load(self.ref_path)
	return self
end

ecs.component "aniref"
	.name "string"
	.weight "real"

ecs.component_alias("pose", "aniref[]")

local m = ecs.transform "animation"
m.input "skeleton"
m.output "animation"
function m.process(e)
	local ske = e.skeleton
	local skehandle = asset.get_resource(ske.ref_path).handle
	local numjoints = #skehandle
	e.animation.aniresult = animodule.new_bind_pose_result(numjoints)
	for posename, pose in pairs(e.animation.pose) do
		pose.name = posename
		pose.weight = nil
		for _, aniref in ipairs(pose) do
			local ani = e.animation.anilist[aniref.name]
			aniref.handle = asset.get_resource(ani.ref_path).handle
			aniref.sampling_cache = animodule.new_sampling_cache(numjoints)
			aniref.start_time = 0
			aniref.duration = aniref.handle:duration() * 1000. / ani.scale
			aniref.max_time = ani.looptimes > 0 and (ani.looptimes * aniref.durations) or math.maxinteger
		end
	end
	local pose = e.animation.pose[e.animation.birth_pose]
	pose.weight = 1
	e.animation.current_pose = {pose}
end

local m = ecs.policy "animation"
m.require_component "animation"
m.require_component "skeleton"
m.require_transform "animation"

ecs.component "animation"
	.anilist "animation_content{}"
	.pose "pose{}"
	.blendtype "string" ("blend")
	.birth_pose "string"

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

function anisystem:update()
	local current_time = timer.from_counter(timer.current_counter)

	for _, eid in world:each("animation") do
		local e = world[eid]
		local ske = asset.get_resource(e.skeleton.ref_path).handle
		local fix_root = true
		local ikcomp = e.ik
		if ikcomp and ikcomp.enable then
			local mat = ms:srtmat(e.transform)
			local t = deep_copy(ikcomp)
			t.target = ms(assert(t.target), "m")
			t.pole_vector = ms(assert(t.pole_vector), "m")
			t.mid_axis = ms(assert(t.mid_axis), "m")
			ik_module.do_ik(mat, ske, t, e.animation.aniresult, fix_root)
		else
			for _, pose in ipairs(e.animation.current_pose) do
				for _, aniref in ipairs(pose) do
					local localtime = current_time - aniref.start_time
					if localtime > aniref.max_time then
						aniref.ratio = 0
					else
						aniref.ratio = localtime % aniref.duration / aniref.duration
					end
				end
			end
			ani_module.motion(ske, e.animation.current_pose, e.animation.blendtype, e.animation.aniresult, nil, fix_root)
		end

		if fix_root then
			local bpresult = e.animation.aniresult
			local rootmat = ms:matrix(bpresult:joint(0))
			--[[
				'>': pop matrix in stack as vec4, column 4 is on top of the stack
				'i': invert col4
			]]
			local inv_t = ms(rootmat, '>iP')
			local invroot_translatemat = ms({type="srt", t=inv_t}, "m")

			bpresult:transform(invroot_translatemat, true)
		end
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
