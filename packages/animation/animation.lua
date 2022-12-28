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
local fs        = require "filesystem"
local datalist  = require "datalist"

local function process_keyframe_event(task)
	if not task then
		return
	end
	if task.play_state.manual_update or not task.play_state.play then return end
	local event_state = task.event_state
	local all_events = event_state.keyframe_events
	local current_events = all_events and all_events[event_state.next_index] or nil
	if not current_events then return end

	local current_time = task.play_state.ratio * task.animation._handle:duration()
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
					local parent
					if task.slot_eid then
						local slot_eid = task.slot_eid[event.link_info.slot_name]
						if slot_eid then
							parent = slot_eid
						end
					end
					event.effect = iefk.create(event.asset_path, {
						auto_play = true,
						scene = {parent = parent},
					})
				elseif event.effect then
					local e <close> = w:entity(event.effect)
					iefk.play(e)
				end
			elseif event.event_type == "Move" then
				for _, eid in ipairs(task.eid) do
					local e0 <close> = w:entity(eid, "scene:in")
					local e1 <close> = w:entity(e0.scene.parent, "scene:in")
					local e2 <close> = w:entity(e1.scene.parent, "scene:in")
					iom.set_position(e2, event.move)
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
	for e in w:select "skeleton:in anim_ctrl:in" do
		local ctrl = e.anim_ctrl
		if ctrl.animation then
			local play_state = ctrl.play_state
			if not play_state.manual_update and play_state.play then
				iani.step(e, delta_time * 0.001)
			end
		end
	end
end

function ani_sys:do_refine()
end

function ani_sys:end_animation()
	for e in w:select "anim_ctrl:in" do
		local ctrl = e.anim_ctrl
		if ctrl.dirty then
			local pr = ctrl.pose_result
			pr:fetch_result()
			pr:end_animation()
			ctrl.dirty = false
		end
	end
end

function ani_sys:data_changed()
	for e in w:select "anim_ctrl:in" do
		process_keyframe_event(e.anim_ctrl)
	end
end

local function load_events(filename)
    local path = string.sub(filename, 1, -6) .. ".event"
    local f = fs.open(fs.path(path))
    if not f then
        return {}
    end
    local data = f:read "a"
    f:close()
    return datalist.parse(data)
end

function ani_sys:component_init()
	for e in w:select "INIT animation:in skeleton:update anim_ctrl:in animation_birth:in eid:in" do
		local ani = e.animation
		for k, v in pairs(ani) do
			ani[k] = assetmgr.resource(v, world)
		end
		e.skeleton = assetmgr.resource(e.skeleton)
		local skehandle = e.skeleton._handle
		local pose_result = animodule.new_pose_result(#skehandle)
		pose_result:setup(skehandle)
		e.anim_ctrl.pose_result = pose_result
		e.anim_ctrl.keyframe_events = {}
		local events = e.anim_ctrl.keyframe_events
		for key, value in pairs(e.animation) do
			events[key] = load_events(tostring(value))
		end
		local anim_name = e.animation_birth
		e.anim_ctrl.animation = e.animation[anim_name]
		e.anim_ctrl.event_state = { next_index = 1, keyframe_events = events[anim_name] }
		e.anim_ctrl.play_state = {
			ratio = 0.0,
			previous_ratio = 0.0,
			speed = 1.0,
			play = false,
			loop = false,
			manual_update = false
		}
		world:pub {"AnimationEvent", "set_time", e.eid, 0}
	end

	for e in w:select "INIT meshskin:update skeleton:update" do
		e.skeleton = assetmgr.resource(e.skeleton)
		local skin = assetmgr.resource(e.meshskin)
		local count = skin.joint_remap and skin.joint_remap:count() or #e.skeleton._handle
		if count > 64 then
			error(("skinning matrices are too large, max is 128, %d needed"):format(count))
		end
		e.meshskin = {
			skin = skin,
			pose = iani.create_pose(),
			skinning_matrices = animodule.new_bind_pose(count)
		}
	end
end

local event_animation = world:sub{"AnimationEvent"}
local function init_prefab_anim(entity)
	local entitys = entity.prefab.tag["*"]
	local anim_eid = {}
	local slot_eid = {}
	local skin_eid
	local ctrl_eid
	for _, eid in ipairs(entitys) do
		local e <close> = w:entity(eid, "meshskin?in anim_ctrl?in skinning?in slot?in name?in")
		if e.meshskin then
			if not skin_eid then
				skin_eid = eid
			end
		elseif e.anim_ctrl then
			ctrl_eid = eid
		elseif e.skinning then
			anim_eid[#anim_eid + 1] = eid
		elseif e.slot then
			slot_eid[e.name] = eid
		end
	end
	local skeleton
	local pose
	if skin_eid then
		local skin <close> = w:entity(skin_eid, "meshskin:in skeleton:in")
		skeleton = skin.skeleton
		pose = skin.meshskin.pose
		pose.skeleton = skeleton
	elseif ctrl_eid then
		local ctrl <close> = w:entity(ctrl_eid, "skeleton:in")
		skeleton = ctrl.skeleton
		pose = iani.create_pose()
		pose.skeleton = skeleton
	end
	for _, eid in pairs(slot_eid) do
		local slot_e <close> = w:entity(eid, "slot:in")
		local slot = slot_e.slot
		if slot.joint_name and skeleton then
			slot.joint_index = skeleton._handle:joint_index(slot.joint_name)
		end
		slot.pose = pose
	end
	if ctrl_eid then
		local ctrl_e <close> = w:entity(ctrl_eid, "anim_ctrl:in")
		local ctrl = ctrl_e.anim_ctrl
		pose.pose_result = ctrl.pose_result
		ctrl.slot_eid = slot_eid
	end
end

function ani_sys:animation_ready()
	for entity in w:select "prefab:in animation_init:in" do
		init_prefab_anim(entity)
	end
	w:clear "animation_init"
end

function ani_sys:entity_ready()
	for _, what, e, p0, p1 in event_animation:unpack() do
		if what == "step" then
			iani.step(e, p0, p1)
		elseif what == "set_time" then
			iani.set_time(e, p0)
		end
	end
end

local mathadapter = import_package "ant.math.adapter"
local math3d_adapter = require "math3d.adapter"
require "skeleton" -- for mathadapter bind
mathadapter.bind(
	"animation",
	function ()
		local mt

		mt = animodule.bind_pose_mt()
		mt.joint = math3d_adapter.getter(mt.joint, "m", 3)

		mt = animodule.pose_result_mt()
		mt.joint = math3d_adapter.getter(mt.joint, "m", 3)
		mt.fetch_result = math3d_adapter.getter(mt.fetch_result, "m", 2)

		mt = animodule.raw_animation_mt()
		mt.push_prekey = math3d_adapter.format(mt.push_prekey, "vqv", 4)

		animodule.build_skinning_matrices = math3d_adapter.matrix(animodule.build_skinning_matrices, 5)
	end)
