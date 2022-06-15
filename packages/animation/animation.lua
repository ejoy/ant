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
	for e in w:select "skeleton:in anim_ctrl:in" do
		local task = e.anim_ctrl._current
		if task.animation then
			local play_state = task.play_state
			if not play_state.manual_update and play_state.play then
				iani.step(task, delta_time * 0.001)
			end
			local ani = task.animation
			local pr = e.anim_ctrl.pose_result
			pr:setup(e.skeleton._handle)
			pr:do_sample(ani._sampling_context, ani._handle, play_state.ratio, task.weight)
		end
	end
end

function ani_sys:do_refine()
end

function ani_sys:end_animation()
	for e in w:select "anim_ctrl:in" do
		local pr = e.anim_ctrl.pose_result
		pr:fetch_result()
		pr:end_animation()
	end
end

function ani_sys:data_changed()
	for e in w:select "anim_ctrl:in" do
		process_keyframe_event(e.anim_ctrl._current)
	end
end

local function load_events(filename, slot_eid)
    local path = string.sub(filename, 1, -6) .. ".event"
    local f = fs.open(fs.path(path))
    if not f then
        return {}
    end
    local data = f:read "a"
    f:close()
    local events = datalist.parse(data)
    for _, evs in pairs(events) do
        for _, ev in ipairs(evs.event_list) do
            if ev.link_info then
                local seid = slot_eid[ev.link_info.slot_name]
                if seid then
                    ev.link_info.slot_eid = seid
                else
                    ev.link_info.slot_name = ""
                end
            end
        end
    end
    return events
end
function ani_sys:component_init()
	for e in w:select "INIT animation:in skeleton:update anim_ctrl:in animation_birth:in" do
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
		-- local events = e.anim_ctrl.keyframe_events
		-- for key, value in pairs(e.animation) do
		-- 	events[key] = load_events(tostring(value), slot_eid)
		-- end
		local anim_name = e.animation_birth
		e.anim_ctrl._current = {
			animation = e.animation[anim_name],
			event_state = { next_index = 1, keyframe_events = {}},--events[anim_name]},
			play_state = {
				ratio = 0.0,
				previous_ratio = 0.0,
				speed = 1.0,
				play = false,
				loop = false,
				manual_update = false
			}
		}
	end
	for e in w:select "INIT meshskin:update skeleton:in" do
		local skin = assetmgr.resource(e.meshskin)
		local count = skin.joint_remap and skin.joint_remap:count() or #e.skeleton._handle
		e.meshskin = {
			skin = skin,
			skinning_matrices = animodule.new_bind_pose(count),
		}
	end
end
local event_animation = world:sub{"AnimationEvent"}
local bgfx = require "bgfx"
local function set_skinning_transform(rc)
	local sm = rc.skinning_matrices
	bgfx.set_multi_transforms(sm:pointer(), sm:count())
end

local function build_transform(rc, skinning)
	rc.skinning_matrices = skinning.skinning_matrices
	rc.set_transform = set_skinning_transform
end

local function init_prefab_anim(entity)
	local entitys = entity.prefab.tag["*"]
	local anim_eid = {}
	-- local slot_eid = {}
	local anim
	for _, eid in ipairs(entitys) do
		local e = world:entity(eid)
		if e.meshskin then
			anim = e
		elseif e.skinning then
			anim_eid[#anim_eid + 1] = eid
		-- elseif e.slot then
		-- 	slot_eid[e.name] = eid
		end
	end
	if anim and #anim_eid > 0 then
		for _, eid in ipairs(anim_eid) do
			build_transform(world:entity(eid).render_object, anim.meshskin)
		end
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
			w:sync("anim_ctrl:in", e)
			iani.step(e.anim_ctrl._current, p0, p1)
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
