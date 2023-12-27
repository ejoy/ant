local ecs = ...
local world = ecs.world
local w     = world.w
local iefk      = ecs.require "ant.efk|efk"
local tl_sys = ecs.system "timeline_system"
local itl = ecs.require "ant.timeline|timeline"
local iani = ecs.require "ant.anim_ctrl|state_machine"
local imodifier = ecs.require "ant.modifier|modifier"

function itl:start(e, context)
	if #e.timeline.key_event <= 0 then
		return 0
	end
	w:extend(e, "start_timeline?out")
	e.start_timeline = true
	e.timeline.context = context
	local tid = itl:alloc()
	e.timeline.tid = tid
	return tid
end

local engine_event = {}

function engine_event:Animation(tid, ud)
	if ud.ev.asset_path and #ud.ev.asset_path > 0 then
		imodifier.start(imodifier.create_modifier_from_file(ud.eid_map[ud.ev.target][1], 0, ud.ev.asset_path, ud.ev.action), {}, true)
	else
		local anim_ctrl = ud.eid_map["anim_ctrl"]
		local anim_eid = anim_ctrl and anim_ctrl[1] or nil
		if anim_eid then
			iani.play(anim_eid, {name = ud.ev.action, forwards = ud.ev.forwards or false})
			if ud.ev.pause_frame and ud.ev.pause_frame > -1 then
				-- TODO: timeline frame ratio is 30
				iani.set_time(anim_eid, ud.ev.pause_frame / 30)
				iani.pause(anim_eid, true)
			end
		end
	end
end

function engine_event:Effect(tid, ud)
	local eid = ud.eid_map[ud.ev.action]
	local e <close> = world:entity(eid[1], "efk:in")
	iefk.play(e)
end

function engine_event:Sound(tid, ud)
end

function engine_event:Message(tid, ud)
	world:pub {"keyframe_event", "message", ud.context}
end

local function add_event(tid, desc)
	for _, ke in ipairs(desc.key_event) do
		for _, event in ipairs(ke.event_list) do
			itl:add(tid, ke.tick, event.event_type, {ev = event, eid_map = desc.eid_map, context = desc.context})
		end
	end
	if desc.loop then
		itl:add(tid, math.floor(desc.duration * 30), "Loop", {loop = desc.loop, duration = desc.duration, key_event = desc.key_event, eid_map = desc.eid_map, context = desc.context})
	end
end

function engine_event:Loop(tid, desc)
	add_event(tid, desc)
end

local function engine_event_handler(t, tid, event, ud)
	local handler = engine_event[event]
	if handler then
		handler(t, tid, ud)
	end
end

function tl_sys.data_changed()
	for e in w:select "start_timeline?out timeline:in" do
		add_event(e.timeline.tid, e.timeline)
		e.new_timeline = false
	end
	itl:update(engine_event_handler)
end

function tl_sys.entity_remove()
	for e in w:select "REMOVED timeline:in" do
		if e.timeline.tid then
			itl:stop(e.timeline.tid)
		end
	end
end