local ecs = ...
local world = ecs.world

local ani_module = require "hierarchy.animation"

local pr_t = ecs.transform "build_pose_result"

function pr_t.process_entity(e)
	local skehandle = e.skeleton._handle
	e.pose_result = ani_module.new_pose_result(#skehandle)
end

local ani_sys = ecs.system "animation_system"

local timer = world:interface "ant.timer|timer"

local fix_root <const> = false

local function do_animation(poseresult, task, delta_time)
	if task.type == 'blend' then
		for _, t in ipairs(task) do
			do_animation(poseresult, t, delta_time)
		end
		poseresult:do_blend("blend", #task, task.weight)
	else
		local ani = task.animation
		local delta = delta_time / ani._duration
		local current_ratio = task.ratio + delta
		task.ratio = current_ratio <= ani._max_ratio and current_ratio or ani._max_ratio
		poseresult:do_sample(ani._sampling_cache, ani._handle, task.ratio % 1, task.weight)
	end
end

local function update_animation(e, delta_time)
	local animation = e.animation
	local ske = e.skeleton
	local pr = e.pose_result
	pr:setup(ske._handle)
	do_animation(pr, animation._current, delta_time)
end

function ani_sys:sample_animation_pose()
	local delta_time = timer.delta()
	for _, eid in world:each "animation" do
		local e = world[eid]
		update_animation(e, delta_time)
	end
end

local function clear_animation_cache()
	for _, eid in world:each "pose_result" do
		local e = world[eid]
		local pr = e.pose_result
		pr:fetch_result()
		pr:end_animation()
	end
end

function ani_sys:do_refine()
	for _, eid in world:each "pose_result" do
		local e = world[eid]
		e.pose_result:fix_root_XZ()
	end
end

function ani_sys:end_animation()
	clear_animation_cache()
end


--TODO
--local m = ecs.interface "animation"
--
--function m.update(e, delta_time)
--	update_animation(e, delta_time or 0)
--	clear_animation_cache()
--end

local mathadapter = import_package "ant.math.adapter"
local math3d_adapter = require "math3d.adapter"

mathadapter.bind(
	"animation",
	function ()
		local bp_mt = ani_module.bind_pose_mt()
		bp_mt.joint = math3d_adapter.getter(bp_mt.joint, "m", 3)

		local pr_mt = ani_module.pose_result_mt()
		pr_mt.joint = math3d_adapter.getter(pr_mt.joint, "m", 3)

		ani_module.build_skinning_matrices = math3d_adapter.matrix(ani_module.build_skinning_matrices, 5)
	end)