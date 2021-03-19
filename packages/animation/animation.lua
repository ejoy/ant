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

local function get_adjust_delta_time(task, delta)
	local clip_state = task.clip_state
	if not clip_state or not clip_state.current or not clip_state.current.clip then return delta end
	local current_time = task.animation._handle:get_time()
	local index = clip_state.current.current_index
	local next_time = current_time + delta * 0.001
	local skip = 0.0
	if next_time > clip_state.current.clip[index].range[2] then
		local index = index + 1
		if index > #clip_state.current.clip then
			index = 1
			skip = task.animation._handle:duration() - clip_state.current.clip[#clip_state.current.clip].range[2] + clip_state.current.clip[index].range[1]
		else
			skip = clip_state.current.clip[index].range[1] - clip_state.current.clip[index - 1].range[2]
		end
		clip_state.current.current_index = index
	elseif index == 1 and next_time < clip_state.current.clip[index].range[1] then
		skip = clip_state.current.clip[index].range[1]
	end
	return skip * 1000 + delta
end

local function process_keyframe_event(task, poseresult)
	local event_state = task.event_state
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
					else
						local final_mat = math3d.mul(math3d.matrix{t = event.collision.offset.position, r = event.collision.offset.rotate, s = {1,1,1}}, iom.worldmat(col.eid))
						iom.set_srt(col.eid, final_mat)
					end
					if event.collision.enable and icoll.test(world[coll.eid]) then
						print("Overlaped!")
					end
				end
			elseif event.event_type == "Effect" then
				if not event.effect_eid and event.asset_path ~= "" then
					local prefab = world:instance(event.asset_path)
					event.effect_eid = prefab[1]
					world[event.effect_eid].parent = event.link_info.slot_eid
				end
				if event.effect_eid and world[event.effect_eid].parent ~= event.link_info.slot_eid then
					world[event.effect_eid].parent = event.link_info.slot_eid
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
		local adjust_time = get_adjust_delta_time(task, delta_time)
		poseresult:do_sample(ani._sampling_context, ani._handle, adjust_time, task.weight)
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

function ani_sys:data_changed()
	local delta_time = timer.delta()
	for _, eid in world:each "animation" do
		local e = world[eid]
		process_keyframe_event(e._animation._current)
	end
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
