local ecs = ...
local world = ecs.world

local asset = import_package "ant.asset".mgr
local ani_module = require "hierarchy.animation"

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack

ecs.component "pose_result"

local pr_p = ecs.policy "pose_result"
pr_p.require_component "skeleton"
pr_p.require_component "pose_result"

pr_p.require_transform "build_pose_result"

local pr_t = ecs.transform "build_pose_result"
pr_t.input "skeleton"
pr_t.output "pose_result"

function pr_t.process(e)
	local ske = asset.get_resource(e.skeleton.ref_path)
	local skehandle = ske.handle
	e.pose_result.result = ani_module.new_bind_pose(#skehandle)
end


--there are 2 types in ik_data, which are 'two_bone'(IKTwoBoneJob) and 'aim'(IKAimJob).
ecs.component "ik_data"
	.name		"string"
	.type		"string"("aim")			-- can be 'two_bone'/'aim'
	.target 	"vector"{0, 0, 0, 1}	-- model space
	.pole_vector"vector"{0, 0, 0, 0}	-- model space
	.twist_angle"real" 	(0.0)
	.weight		"real"  (0.0)
	.joints		"string[]"{}			-- type == 'aim', #joints == 1, type == 'two_bone', #joints == 3, with start/mid/end
	["opt"].mid_axis"vector" {0, 0, 1, 0}
	["opt"].soften "real" 	(0.0)
	["opt"].up_axis"vector" {0, 1, 0, 0}
	["opt"].forward "vector"{0, 0, 1, 0}-- local space
	["opt"].offset "vector" {0, 0, 0, 0}-- local space

ecs.component "ik"
	.jobs 'ik_data[]'

local ik_p = ecs.policy "ik"
ik_p.require_component "skeleton"
ik_p.require_component "ik"
ik_p.require_component "pose_result"
ik_p.require_transform "build_pose_result"
ik_p.require_transform "build_ik"

ik_p.require_system "ik_system"

ik_p.require_policy "pose_result"

local build_ik_tranform = ecs.transform "build_ik"
build_ik_tranform.input "skeleton"
build_ik_tranform.output "ik"

local function check_joints_in_hierarchy_chain(ske, joint_indices)
	for i=3, 2, -1 do
		local jidx = joint_indices[i]
		local pidx = ske:parent(jidx)

		local next_jidx = joint_indices[i-1]
		while pidx ~= next_jidx and pidx ~= 0 do
			pidx = ske:parent(pidx)
		end

		if pidx == 0 then
			error(string.format("ik joints can not use as foot ik, which joints must as parent clain:%d %d %d", joint_indices[1], joint_indices[2], joint_indices[3]))
		end
	end
end

function build_ik_tranform.process(e)
	local ske = asset.get_resource(e.skeleton.ref_path).handle
	local ik = e.ik

	for _, ikdata in ipairs(ik.jobs) do
		local joint_indices = {}
		for _, jn in ipairs(ikdata.joints) do
			local jointidx = ske:joint_index(jn)
			if jointidx == nil then
				error(string.format("invalid joint name:%s", jn))
			end

			joint_indices[#joint_indices+1] = jointidx
		end

		if e.ik.type == "two_bone" then
			assert(#joint_indices == 3)

			check_joints_in_hierarchy_chain(joint_indices)
		end
		ikdata.joint_indices = joint_indices
	end
end

ecs.component "animation_content"
	.ref_path "respath"
	.scale "real" (1)
	.looptimes "int" (0)

local ap = ecs.policy "animation"
ap.require_component "skeleton"
ap.require_component "animation"
ap.require_component "pose_result"
ap.require_transform "build_pose_result"

ap.require_system "animation_system"

ap.require_policy "pose_result"

local anicomp = ecs.component "animation"
	.anilist "animation_content{}"
	.birth_pose "string"

function anicomp:init()
	for name, ani in pairs(self.anilist) do
		ani.handle = asset.get_resource(ani.ref_path).handle
		ani.sampling_cache = ani_module.new_sampling_cache()
		ani.duration = ani.handle:duration() * 1000. / ani.scale
		ani.max_time = ani.looptimes > 0 and (ani.looptimes * ani.duration) or math.maxinteger
		ani.name = name
	end
	self.current = {
		animation = self.anilist[self.birth_pose],
		start_time = 0,
	}
	return self
end

ecs.component_alias("skeleton", "resource")

local anisystem = ecs.system "animation_system"
anisystem.require_interface "ant.timer|timer"

local timer = world:interface "ant.timer|timer"

local ikdata_cache = {}
local function prepare_ikdata(ikdata)
	ikdata_cache.type		= ikdata.type
	ikdata_cache.target 	= ~ikdata.target
	ikdata_cache.pole_vector= ~ikdata.pole_vector
	ikdata_cache.weight		= ikdata.weight
	ikdata_cache.twist_angle= ikdata.twist_angle
	ikdata_cache.joint_indices= ikdata.joint_indices

	if ikdata.type == "aim" then
		ikdata_cache.forward	= ~ikdata.forward
		ikdata_cache.up_axis	= ~ikdata.up_axis
		ikdata_cache.offset		= ~ikdata.offset
	else
		assert(ikdata.type == "two_bone")
		ikdata_cache.soften		= ikdata.soften
		ikdata_cache.mid_axis	= ~ikdata.mid_axis
	end
	return ikdata_cache
end

local fix_root <const> = true

function anisystem:sample_animation_pose()
	local current_time = timer.current()

	local function do_animation(task)
		if task.type == 'blend' then
			for _, t in ipairs(task) do
				do_animation(t)
			end
			ani_module.do_blend("blend", #task, task.weight)
		else
			local ani = task.animation
			local localtime = current_time - task.start_time
			local ratio = 0
			if localtime <= ani.max_time then
				ratio = localtime % ani.duration / ani.duration
			end
			ani_module.do_sample(ani.sampling_cache, ani.handle, ratio, task.weight)
		end
	end

	for _, eid in world:each "animation" do
		local e = world[eid]
		local animation = e.animation
		local ske = asset.get_resource(e.skeleton.ref_path)

		ani_module.setup(e.pose_result.result, ske.handle, fix_root)
		do_animation(animation.current)
		ani_module.fetch_result()
	end
end

local ik_i = ecs.interface "ik"
local current_ikjob_info
function ik_i.set_ikinfo(ikjob_info)
	current_ikjob_info = ikjob_info
end

function ik_i.get_ikinfo()
	return current_ikjob_info
end

function ik_i.clear()
	current_ikjob_info = nil
end

local iik = world:interface "ant.animation|ik"

local iksys = ecs.system "ik_system"
iksys.require_interface "ant.animation|ik"

local ik_group = world:update_func "ik_group"

function iksys:do_ik()
	for _, eid in world:each "ik" do
		local e = world[eid]
		local ikcomp = e.ik
		local skehandle = asset.get_resource(e.skeleton.ref_path).handle
		
		ani_module.setup(e.pose_result.result, skehandle, fix_root)
		for _, ikdata in ipairs(ikcomp.jobs) do
			iik.set_ikinfo {eid = eid, ikdata=ikdata}
			ik_group()
		end
	end
end

function iksys:compute_ik()
	local ikinfo = iik.get_ikinfo()
	if ikinfo then
		local ikdata = ikinfo.ikdata
		if ikdata.enable then
			ani_module.do_ik(prepare_ikdata(ikdata))
		end
	end
end

function anisystem:end_animation()
	ani_module.end_animation()
end