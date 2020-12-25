local ecs = ...
local world = ecs.world
local icoll     = world:interface "ant.collision|collider"
local assetmgr 		= import_package "ant.asset"
local iom 			= world:interface "ant.objcontroller|obj_motion"
local ani_module 	= require "hierarchy.animation"
local math3d 		= require "math3d"
local ani_cache = ecs.transform "animation_transform"
function ani_cache.process_entity(e)
	e._animation = {}
end

local pr_t = ecs.transform "build_pose_result"

function pr_t.process_entity(e)
	local skehandle = e.skeleton._handle
	e.pose_result = ani_module.new_pose_result(#skehandle)
end

local ani_sys = ecs.system "animation_system"

local timer = world:interface "ant.timer|timer"

local fix_root <const> = false

local function process_keyframe_event(task, poseresult)
	local event_state = task.event_state
	if not event_state.keyframe_events then return end
	-- local delta = delta_time / ani._duration
	-- local current_ratio = task.ratio + delta
	-- task.ratio = current_ratio <= ani._max_ratio and current_ratio or ani._max_ratio
	-- poseresult:do_sample(ani._sampling_cache, ani._handle, task.ratio % 1, task.weight)
	local colliders = event_state.keyframe_events.collider
	if colliders then
		for _, coll in ipairs(colliders) do
			if coll.joint_index > 0 then
				local tranform = poseresult:joint(coll.joint_index)
				local _, origin_r, origin_t = math3d.srt(tranform)
				local origin_s, _, _ = math3d.srt(iom.worldmat(coll.eid))
				iom.set_srt(coll.eid, math3d.matrix{ s = origin_s, r = origin_r, t = origin_t })
			else
			end
		end
	end

	local all_events = event_state.keyframe_events.event
	local current_events = all_events and all_events[event_state.next_index] or nil
	if not current_events then return end

	local current_time = task.animation._handle:get_time()
	if current_time < current_events.time and event_state.finish then
		-- restart
		event_state.next_index = 1
		event_state.finish = false
	end
	while not event_state.finish and current_events.time <= current_time do
		for _, event in ipairs(current_events.event_list) do
			--print("event trigger : ", current_time, event.name, event.event_type)
			if event.event_type == "Collision" then
				local col = event.collision.collider--colliders[event.collision.collider_index]
				if col then
					if col.joint_index == 0 then
						local origin_s, _, _ = math3d.srt(iom.worldmat(col.eid))
						iom.set_srt(col.eid, math3d.matrix{ s = origin_s, r = event.collision.offset.rotate, t = event.collision.offset.position })
						--print("transform 1")
					else
						local final_mat = math3d.mul(math3d.matrix{t = event.collision.offset.position, r = event.collision.offset.rotate, s = {1,1,1}}, iom.worldmat(col.eid))
						iom.set_srt(col.eid, final_mat)
						--print("transform 2")
					end
					if event.collision.enable and icoll.test(world[coll.eid]) then
						print("Overlaped!")
					end
				end
			end
		end
		event_state.next_index = event_state.next_index + 1
		if event_state.next_index > #all_events then
			event_state.next_index = #all_events
			event_state.finish = true
			break
		end
		current_events = all_events[event_state.next_index]
	end
end

local function do_animation(poseresult, task, delta_time)
	if task.type == 'blend' then
		for _, t in ipairs(task) do
			do_animation(poseresult, t, delta_time)
		end
		poseresult:do_blend("blend", #task, task.weight)
	else
		local ani = task.animation
		poseresult:do_sample(ani._sampling_cache, ani._handle, delta_time, task.weight)
		process_keyframe_event(task, poseresult)
	end
end

local function update_animation(e, delta_time)
	local ske = e.skeleton
	local pr = e.pose_result
	pr:setup(ske._handle)
	do_animation(pr, e._animation._current, delta_time)
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


local m = ecs.component "animation"

function m:init()
	local res = {}
	for k, v in pairs(self) do
		res[k] = assetmgr.resource(v)
	end
	return res
end
