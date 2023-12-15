local ecs = ...
local world = ecs.world
local w     = world.w
local iefk      = ecs.require "ant.efk|efk"
local tl_sys = ecs.system "timeline_system"
local itl = ecs.require "ant.timeline|timeline"
local iani = ecs.require "ant.anim_ctrl|state_machine"

function itl.start(e, context)
	w:extend(e, "start_timeline?out")
	e.start_timeline = true
	e.timeline.context = context
end

local engine_event = {}

function engine_event:Animation(tid, ud)
	local anim_eid = ud.eid_map["anim_eid"]
	-- TODO: rework this code
	-- for _, eid in ipairs(entitys) do
	-- 	local e <close> = world:entity(eid, "anim_ctrl?in")
		if anim_eid then
			iani.play(anim_eid, {name = ud.ev.asset_path, forwards = ud.ev.forwards or false})
			if ud.ev.pause_frame and ud.ev.pause_frame > -1 then
				iani.set_time(anim_eid, ud.ev.pause_frame)
				iani.pause(anim_eid, true)
			end
			-- print("event animation : ", ud.ev.name, ud.ev.asset_path)
			-- break
		end
	-- end
end

function engine_event:Effect(tid, ud)
	local eid = ud.eid_map[ud.ev.asset_path]
	local e <close> = world:entity(eid[1], "efk:in")
	iefk.play(e)
	-- print("event effect : ", ud.ev.name, ud.ev.asset_path)
end

function engine_event:Sound(tid, ud)
	-- print("event sound : ", ud.ev.name, ud.ev.asset_path)
end

function engine_event:Message(tid, ud)
	-- print("event message : ", ud.ev.name, ud.ev.msg_content)
	world:pub {"keyframe_event", "message", ud.context}
end

local function add_event(tid, desc)
	for _, ke in ipairs(desc.key_event) do
		for _, event in ipairs(ke.event_list) do
			itl:add(tid, ke.tick, event.event_type, {ev = event, eid_map = desc.eid_map, context = desc.context})
			-- print("add timeline : ", tid, ke.tick, event.event_type)
		end
	end
	if desc.loop then
		itl:add(tid, math.floor(desc.duration * 30), "Loop", {loop = desc.loop, duration = desc.duration, key_event = desc.key_event, eid_map = e.timeline.eid_map, context = e.timeline.context})
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
		local tid
		if #e.timeline.key_event > 0 then
			tid = itl:alloc()
		end
		-- for _, ke in ipairs(e.timeline.key_event) do
		-- 	for _, event in ipairs(ke.event_list) do
		-- 		itl:add(tid, ke.tick, event.event_type, {ev = event, eid_map = e.timeline.eid_map, context = e.timeline.context})
		-- 		-- print("add timeline : ", tid, ke.tick, event.event_type)
		-- 	end
		-- end
		-- if e.timeline.loop then
		-- 	itl:add(tid, math.floor(e.timeline.duration * 30), "Loop", {loop = e.timeline.loop, duration = e.timeline.duration, key_event = e.timeline.key_event, eid_map = e.timeline.eid_map, context = e.timeline.context})
		-- end
		add_event(tid, e.timeline)
		e.new_timeline = false
	end
	itl:update(engine_event_handler)
end