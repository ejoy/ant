local ecs = ...
local world = ecs.world
--local icoll     = world:interface "ant.collision|collider"
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

local timer = world:interface "ant.timer|itimer"

local fix_root <const> = false

local function get_current_anim_time(task)
	return task.play_state.ratio * task.animation._handle:duration()
end

local function process_keyframe_event(task)
	if task.play_state.manual_update then return end
	local event_state = task.event_state
	local all_events = event_state.keyframe_events
	local current_events = all_events and all_events[event_state.next_index] or nil
	if not current_events then return end

	local current_time = get_current_anim_time(task)
	if current_time < current_events.time and event_state.finish then
		-- restart
		event_state.next_index = 1
		event_state.finish = false
	end
	while not event_state.finish and current_events.time <= current_time do
		for _, event in ipairs(current_events.event_list) do
			--print("event trigger : ", current_time, event.name, event.event_type)
			if event.event_type == "Collision" then
				local collision = event.collision--colliders[event.collision.collider_index]
				if collision and collision.col_eid and collision.col_eid ~= -1 then
					-- if collision.joint_index == 0 then
					-- 	local origin_s, _, _ = math3d.srt(iom.worldmat(collision.col_eid))
					-- 	iom.set_srt(collision.eid, math3d.matrix{ s = origin_s, r = event.collision.offset.rotate, t = event.collision.offset.position })
					-- else
					-- 	local final_mat = math3d.mul(math3d.matrix{t = event.collision.position, r = event.collision.offset.rotate, s = {1,1,1}}, iom.worldmat(col.eid))
					-- 	iom.set_srt(collision.eid, final_mat)
					-- end
					local eid = collision.col_eid
            		iom.set_position(eid, collision.position)
            		local factor = (collision.shape_type == "sphere") and 100 or 200
            		iom.set_scale(eid, {collision.size[1] * factor, collision.size[2] * factor, collision.size[3] * factor})
				end
			elseif event.event_type == "Effect" then
				if not event.effect and event.asset_path ~= "" then
					event.effect = world:prefab_instance(event.asset_path)
					world:prefab_event(event.effect, "set_parent", "root", event.link_info.slot_eid)
				end
				if event.effect then
					local parent = world:prefab_event(event.effect, "get_parent", "root")
					if event.link_info.slot_eid and parent ~= event.link_info.slot_eid then
						world:prefab_event(event.effect, "set_parent", "root", event.link_info.slot_eid)
					end
					world:prefab_event(event.effect, "play", "root", "", false, not task.play_state.play)
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

local iani = world:interface "ant.animation|animation"
local function do_animation(poseresult, task, delta_time)
	if task.type == 'blend' then
		for _, t in ipairs(task) do
			do_animation(poseresult, t, delta_time)
		end
		poseresult:do_blend("blend", #task, task.weight)
	else
		local play_state = task.play_state
		if not play_state.manual_update and play_state.play then 
			iani.step(task, delta_time * 0.001)
		end
		local ani = task.animation
		poseresult:do_sample(ani._sampling_context, ani._handle, play_state.ratio, task.weight)
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
	-- for _, eid in world:each "pose_result" do
	-- 	local e = world[eid]
	-- 	if e.animation.fix_root_XZ then
	-- 		e.pose_result:fix_root_XZ()
	-- 	end
	-- end
end

function ani_sys:end_animation()
	clear_animation_cache()
end

function ani_sys:data_changed()
	local delta_time = timer.delta()
	for _, eid in world:each "animation" do
		process_keyframe_event(world[eid]._animation._current)
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
