local ecs = ...
local world = ecs.world
local w = world.w

local assetmgr 		= import_package "ant.asset"
local iom 			= world:interface "ant.objcontroller|obj_motion"
local animodule 	= require "hierarchy.animation"


local ani_sys = ecs.system "animation_system"

local timer = world:interface "ant.timer|itimer"

local fix_root <const> = false

local function get_current_anim_time(task)
	return task.play_state.ratio * task.animation._handle:duration()
end

local function process_keyframe_event(task)
	if task.play_state.manual_update or not task.play_state.play then return end
	local event_state = task.event_state
	local all_events = event_state.keyframe_events
	local current_events = all_events and all_events[event_state.next_index] or nil
	if not current_events then return end

	local current_time = get_current_anim_time(task)
	if current_time < current_events.time and event_state.finish then
		event_state.next_index = 1
		event_state.finish = false
	end
	while not event_state.finish and current_events.time <= current_time do
		for _, event in ipairs(current_events.event_list) do
			if event.event_type == "Collision" then
				local collision = event.collision
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
					local eeid = world:prefab_event(event.effect, "get_eid", "root")
					local effect = world[eeid].effect_instance
					if effect then
						effect.auto_play = false
					end
					world:prefab_event(event.effect, "set_parent", "root", event.link_info.slot_eid)
				end
				if event.effect then
					local parent = world:prefab_event(event.effect, "get_parent", "root")
					if event.link_info.slot_eid and parent ~= event.link_info.slot_eid then
						world:prefab_event(event.effect, "set_parent", "root", event.link_info.slot_eid)
					end
					world:prefab_event(event.effect, "play", "root", "", false, false)
					if task.play_state.play then
						world:prefab_event(event.effect, "speed", "root", task.play_state.speed or 1.0)
					end
				end
			elseif event.event_type == "Move" then
				iom.set_position(world[world[task.eid].parent].parent, event.move)
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

function ani_sys:sample_animation_pose()
	local delta_time = timer.delta()
	for e in w:select "skeleton:in pose_result:in _animation:in" do
		local ske = e.skeleton
		local pr = e.pose_result
		pr:setup(ske._handle)
		do_animation(pr, e._animation._current, delta_time)
	end
end

function ani_sys:do_refine()
end

function ani_sys:end_animation()
	for e in w:select "pose_result:in" do
		local pr = e.pose_result
		pr:fetch_result()
		pr:end_animation()
	end
end

function ani_sys:data_changed()
	for e in w:select "_animation:in" do
		process_keyframe_event(e._animation._current)
	end
end

function ani_sys:component_init()
	for e in w:select "INIT animation:in skeleton:update pose_result:out" do
		local ani = e.animation
		for k, v in pairs(ani) do
			ani[k] = assetmgr.resource(v)
		end
		e.skeleton = assetmgr.resource(e.skeleton)
		local skehandle = e.skeleton._handle
		e.pose_result = animodule.new_pose_result(#skehandle)
	end
end
local event_set_clips = world:sub{"SetClipsEvent"}
local event_animation = world:sub{"AnimationEvent"}
local event_do_play = world:sub{"do_play_animation"}

function ani_sys:entity_ready()
	-- for _, eh, lp in event_do_play:unpack() do
    --     effekseer.set_loop(eh, lp)
    --     effekseer.play(eh)
    -- end
    for _, p, p0, p1 in event_set_clips:unpack() do
		world:prefab_event(p, "set_clips", p0, p1)
	end
	for _, what, eid, p0, p1, p2 in event_animation:unpack() do
		if what == "play_group" then
			iani.play_group(eid, p0, p1, p2)
		elseif what == "step" then
			for e in world.w:select "eid:in" do
				if e.eid == eid then
					world.w:sync("_animation:in", e)
					iani.step(e._animation._current, p0, p1)
				end
			end
		elseif what == "set_time" then
			iani.set_time(eid, p0)
		end
	end
end

local mathadapter = import_package "ant.math.adapter"
local math3d_adapter = require "math3d.adapter"

mathadapter.bind(
	"animation",
	function ()
		local bp_mt = animodule.bind_pose_mt()
		bp_mt.joint = math3d_adapter.getter(bp_mt.joint, "m", 3)

		local pr_mt = animodule.pose_result_mt()
		pr_mt.joint = math3d_adapter.getter(pr_mt.joint, "m", 3)

		animodule.build_skinning_matrices = math3d_adapter.matrix(animodule.build_skinning_matrices, 5)
	end)
