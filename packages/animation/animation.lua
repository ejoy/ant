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
		ani.max_ratio = ani.looptimes > 0 and ani.looptimes or math.maxinteger
		ani.name = name
	end
	return self
end

ecs.component_alias("skeleton", "resource")

local anisystem = ecs.system "animation_system"
anisystem.require_interface "ant.timer|timer"

local timer = world:interface "ant.timer|timer"

local fix_root <const> = true

local function do_animation(task, delta_time)
	if task.type == 'blend' then
		for _, t in ipairs(task) do
			do_animation(t, delta_time)
		end
		ani_module.do_blend("blend", #task, task.weight)
	else
		local ani = task.animation
		local delta = delta_time / ani.duration
		local current_ratio = task.ratio + delta
		task.ratio = current_ratio <= ani.max_ratio and current_ratio or ani.max_ratio
		ani_module.do_sample(ani.sampling_cache, ani.handle, task.ratio % 1, task.weight)
	end
end

local function update_animation(e, delta_time)
	local animation = e.animation
	local ske = asset.get_resource(e.skeleton.ref_path)
	ani_module.setup(e.pose_result.result, ske.handle, fix_root)
	do_animation(animation.current, delta_time)
	ani_module.fetch_result()
end

function anisystem:sample_animation_pose()
	local delta_time = timer.delta()
	for _, eid in world:each "animation" do
		local e = world[eid]
		update_animation(e, delta_time)
	end
end

function anisystem:end_animation()
	ani_module.end_animation()
end

local m = ecs.interface "animation"

function m.update(e, delta_time)
	update_animation(e, delta_time or 0)
	ani_module.clean_cache()
end

local mathadapter = import_package "ant.math.adapter"
local math3d_adapter = require "math3d.adapter"

mathadapter.bind(
	"animation",
	function ()
		local bp_mt = ani_module.bind_pose_mt()
		bp_mt.joint = math3d_adapter.getter(bp_mt.joint, "m", 3)
	end)