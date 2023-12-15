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
	local entitys = ud.eid_map["*"]
	-- TODO: rework this code
	for _, eid in ipairs(entitys) do
		local e <close> = world:entity(eid, "anim_ctrl?in")
		if e.anim_ctrl then
			iani.play(eid, {name = ud.ev.asset_path, forwards = ud.ev.forwards or false})
			if ud.ev.pause_frame > -1 then
				iani.set_time(eid, ud.ev.pause_frame)
				iani.pause(eid, true)
			end
			-- print("event animation : ", ud.ev.name, ud.ev.asset_path)
			break
		end
	end
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
	print("event message : ", ud.ev.name, ud.ev.msg_content)
	world:pub {"keyframe_event", "message", ud.context}
end

local testtid
local ev = {}
function ev:test(tid, ud)
	print("test", ud)
end

function ev:cancel(tid, ud)
	self:stop(tid)
end

function ev:again(tid, ud)
	itl:add(tid, 0, "test")
	itl:add(tid, 20, "again")
end

local function test_event_handler(t, tid, event, ud)
	ev[event](t, tid, ud)
end

local function engine_event_handler(t, tid, event, ud)
	local handler = engine_event[event]
	if handler then
		handler(t, tid, ud)
	end
end
local start_tick = 0
function tl_sys.data_changed()
	for e in w:select "start_timeline?out timeline:in" do
		local tid
		if #e.timeline.key_event > 0 then
			tid = itl:alloc()
		end
		for _, ke in ipairs(e.timeline.key_event) do
			for _, event in ipairs(ke.event_list) do
				itl:add(tid, ke.tick, event.event_type, {ev = event, eid_map = e.timeline.eid_map, context = e.timeline.context})
				-- print("add timeline : ", ke.tick, event.event_type)
			end
		end
		e.new_timeline = false
	end
	itl:update(engine_event_handler)
	-- if not testtid then
	-- 	testtid = itl:alloc()
	-- 	itl:add(testtid, 0, "test")
	-- 	itl:add(testtid, 20, "again")
	-- end
	-- itl:update(test_event_handler)
end