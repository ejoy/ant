local ecs = ...
local world = ecs.world

local asset = import_package "ant.asset".mgr
local ani_module = require "hierarchy.animation"

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

function anicomp:init()
	for name, ani in pairs(self.anilist) do
		ani.handle = asset.get_resource(ani.ref_path).handle
		ani.sampling_cache = ani_module.new_sampling_cache()
		ani.duration = ani.handle:duration() * 1000. / ani.scale
		ani.max_time = ani.looptimes > 0 and (ani.looptimes * ani.duration) or math.maxinteger
		ani.name = name
	end
	return self
end

ecs.component_alias("skeleton", "resource")

local anisystem = ecs.system "animation_system"
anisystem.require_interface "ant.timer|timer"

local timer = world:interface "ant.timer|timer"

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

function anisystem:end_animation()
	ani_module.end_animation()
end
