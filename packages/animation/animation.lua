local ecs = ...
local world = ecs.world

local asset = import_package "ant.asset".mgr
local timer = import_package "ant.timer"
local ani_module = require "hierarchy.animation"

ecs.component "animation_content"
	.ref_path "respath"
	.scale "real" (1)
	.looptimes "int" (0)

ecs.component "aniref"
	.name "string"
	.weight "real"

ecs.component_alias("pose", "aniref[]")

ecs.component "pose_result"

local t_pr = ecs.transform "pose_result"
t_pr.input "skeleton"
t_pr.output "pose_result"
function t_pr.process(e)
	local skehandle = asset.get_resource(e.skeleton.ref_path).handle
	e.pose_result.result = ani_module.new_bind_pose(#skehandle)
end

local ap = ecs.policy "animation"
ap.require_component "skeleton"
ap.require_component "animation"
ap.require_component "pose_result"
ap.require_transform "pose_result"

ap.require_system "animation_system"

local anicomp = ecs.component "animation"
	.anilist "animation_content{}"
	.pose "pose{}"
	.blendtype "string" ("blend")
	.birth_pose "string"

function anicomp:init()
	local pose = {}
	for name, ani in pairs(self.anilist) do
		local aniref = {}
		aniref.handle = asset.get_resource(ani.ref_path).handle
		aniref.sampling_cache = ani_module.new_sampling_cache()
		aniref.start_time = 0
		aniref.duration = aniref.handle:duration() * 1000. / ani.scale
		aniref.max_time = ani.looptimes > 0 and (ani.looptimes * aniref.durations) or math.maxinteger
		pose[name] = {name = name, aniref}
	end
	self.pose = pose
	local birth_pose = self.pose[self.birth_pose]
	birth_pose.weight = 1
	self.current_pose = {birth_pose}
	return self
end

ecs.component_alias("skeleton", "resource")

local anisystem = ecs.system "animation_system"

function anisystem:sample_animation_pose()
	local current_time = timer.from_counter(timer.current_counter)
	for _, eid in world:each "animation" do
		local e = world[eid]
		local ske = asset.get_resource(e.skeleton.ref_path).handle
		local fix_root <const> = true

		local posresult = e.pose_result

		local animation = e.animation
		for _, pose in ipairs(animation.current_pose) do
			for _, aniref in ipairs(pose) do
				local localtime = current_time - aniref.start_time
				if localtime > aniref.max_time then
					aniref.ratio = 0
				else
					aniref.ratio = localtime % aniref.duration / aniref.duration
				end
			end
		end
		ani_module.motion(ske, animation.current_pose, "blend", posresult.result, nil, fix_root)
	end
end
