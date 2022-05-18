local ecs 	= ...
local world = ecs.world
local w 	= world.w

local assetmgr 		= import_package "ant.asset"
local iom 			= ecs.import.interface "ant.objcontroller|iobj_motion"
local animodule 	= require "hierarchy".animation

local ani_sys 		= ecs.system "animation_system"
local timer 		= ecs.import.interface "ant.timer|itimer"
local iefk          = ecs.import.interface "ant.efk|iefk"
-- local iaudio    	= ecs.import.interface "ant.audio|audio_interface"

local function get_current_anim_time(task)
	return task.play_state.ratio * task.animation._handle:duration()
end

local function process_keyframe_event(task)
	if not task then
		return
	end
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
			if event.event_type == "Sound" then
				-- iaudio.play(event.sound_event)
			elseif event.event_type == "Collision" then
				local collision = event.collision
				if collision and collision.col_eid and collision.col_eid ~= -1 then
					local eid = collision.col_eid
            		iom.set_position(eid, collision.position)
            		local factor = (collision.shape_type == "sphere") and 100 or 200
            		iom.set_scale(eid, {collision.size[1] * factor, collision.size[2] * factor, collision.size[3] * factor})
				end
			elseif event.event_type == "Effect" then
				if not event.effect and event.asset_path ~= "" then
					event.effect = iefk.create(event.asset_path, {play_on_create = true})
					if event.link_info.slot_eid then
						ecs.method.set_parent(event.effect, event.link_info.slot_eid)
					end
				elseif event.effect then
					iefk.play(world:entity(event.effect))
				end
			elseif event.event_type == "Move" then
				for _, eid in ipairs(task.eid) do
					w:sync("scene:in", eid)
					local pn = eid.scene.parent
					w:sync("scene:in", pn)
					iom.set_position(pn.scene.parent, event.move)
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

local iani = ecs.import.interface "ant.animation|ianimation"

function ani_sys:sample_animation_pose()
	local delta_time = timer.delta()
	for e in w:select "skeleton:in meshskin:in _animation:in" do
		local task = e._animation._current
		if task then
			local play_state = task.play_state
			if not play_state.manual_update and play_state.play then
				iani.step(task, delta_time * 0.001)
			end
			local ani = task.animation
			local pr = e.meshskin.pose_result
			pr:setup(e.skeleton._handle)
			pr:do_sample(ani._sampling_context, ani._handle, play_state.ratio, task.weight)
		end
	end
end

function ani_sys:do_refine()
end

function ani_sys:end_animation()
	for e in w:select "meshskin:in" do
		local pr = e.meshskin.pose_result
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
	for e in w:select "INIT animation:in skeleton:update meshskin:update" do
		local ani = e.animation
		for k, v in pairs(ani) do
			ani[k] = assetmgr.resource(v, world)
		end
		e.skeleton = assetmgr.resource(e.skeleton)
		local skehandle = e.skeleton._handle
		local pose_result = animodule.new_pose_result(#skehandle)
		pose_result:setup(skehandle)
		local skin = assetmgr.resource(e.meshskin)
		local count = skin.joint_remap and skin.joint_remap:count() or pose_result:count()
		e.meshskin = {
			skin = skin,
			pose_result = pose_result,
			skinning_matrices = animodule.new_bind_pose(count),
		}
	end
end
local event_set_clips = world:sub{"SetClipsEvent"}
local event_animation = world:sub{"AnimationEvent"}
local eventPrefabReady = world:sub{"prefab_ready"}
local bgfx = require "bgfx"
local function set_skinning_transform(rc)
	local sm = rc.skinning_matrices
	bgfx.set_multi_transforms(sm:pointer(), sm:count())
end

local function build_transform(rc, skinning)
	rc.skinning_matrices = skinning.skinning_matrices
	rc.set_transform = set_skinning_transform
end

function ani_sys:animation_ready()
	for e in w:select "prefab:in animation_init:in" do
		local entitys = e.prefab.tag["*"]
		local anim_e = {}
		local anim
		for _, eid in ipairs(entitys) do
			local e = world:entity(eid)
			if e._animation then
				anim = e
			elseif e.skinning then
				anim_e[#anim_e + 1] = eid
			end
		end
		if anim and #anim_e > 0 then
			anim._animation.anim_e = anim_e
			for _, eid in ipairs(anim_e) do
				build_transform(world:entity(eid).render_object, anim.meshskin)
			end
			local anim_name = anim.animation_birth
			anim._animation._current = {
				animation = anim.animation[anim_name],
				event_state = {
					next_index = 1,
					keyframe_events = anim._animation.keyframe_events and anim._animation.keyframe_events[anim_name] or {}
				},
				play_state = { ratio = 0.0, previous_ratio = 0.0, speed = 1.0, play = false, loop = false, manual_update = false }
			}
		end
	end
	w:clear "animation_init"
end

function ani_sys:entity_ready()
    for _, p, p0, p1 in event_set_clips:unpack() do
		world:prefab_event(p, "set_clips", p0, p1)
	end
	for _, what, e, p0, p1, p2 in event_animation:unpack() do
		if what == "play_group" then
			iani.play_group(e, p0, p1, p2)
		elseif what == "play_clip" then
			iani.play_clip(e, p0, p1, p2)
		elseif what == "step" then
			w:sync("_animation:in", e)
			iani.step(e._animation._current, p0, p1)
		elseif what == "set_time" then
			iani.set_time(e, p0)
		end
	end
end

local mathadapter = import_package "ant.math.adapter"
local math3d_adapter = require "math3d.adapter"

mathadapter.bind(
	"animation",
	function ()
		local mt

		mt = animodule.bind_pose_mt()
		mt.joint = math3d_adapter.getter(mt.joint, "m", 3)

		mt = animodule.pose_result_mt()
		mt.joint = math3d_adapter.getter(mt.joint, "m", 3)

		mt = animodule.raw_animation_mt()
		mt.push_prekey = math3d_adapter.format(mt.push_prekey, "vqv", 4)

		animodule.build_skinning_matrices = math3d_adapter.matrix(animodule.build_skinning_matrices, 5)
	end)
