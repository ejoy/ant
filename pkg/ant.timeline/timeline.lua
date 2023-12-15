local timeline = {}; timeline.__index = timeline

function timeline:alloc()
	local tid = self._tid + 1
	self._tid = tid
	return tid
end

-- 1: play(event)
-- 2: play { tick = 0, event = event }
-- 3: play {
--		{ tick = 0, event = event1 },
--		{ tick = 10, event = event2 },
--	}
function timeline:play(events, ud)
	local tid = self:alloc()
	if type(events) == "string" then
		self:add(tid, 0, events, ud)
	elseif events.tick then
		self:add(tid, events.tick, events.event, ud)
	else
		for _, ev in ipairs(events) do
			self:add(tid, ev.tick, ev.event, ud)
		end
	end
	return tid
end

function timeline:add(tid, tick, event, ud)
	local last_n = self._timeline[tid] or 0
	local t = self._tick + tick
	local ev = {
		tid = tid,
		event = event,
		ud = ud,
	}
	local f = self._event[t]
	if f then
		ev.next = f
	end
	self._event[t] = ev
	self._timeline[tid] = last_n + 1
end

function timeline:stop(tid)
	local n = self._timeline[tid]
	if n then
		self._stop[tid] = true
	end
end

local function run(self, func, f)
	if f.next then
		run(self, func, f.next)
	end
	local tid = f.tid
	if not self._stop[tid] then
		func(self, tid, f.event, f.ud)
	end

	local n = self._timeline[tid]
	if n <= 1 then
		self._timeline[tid] = nil
		self._stop[tid] = nil
	else
		self._timeline[tid] = n - 1
	end
end

function timeline:update(func)
	local t = self._tick
	local ev = self._event
	local f = ev[t]
	while f do
		ev[t] = nil
		run(self, func, f)
		f = ev[t]
	end
	self._tick = t + 1
end

function timeline.new()
	local t = {
		_tid = 0,
		_tick = 0,
		_timeline = {},
		_stop = {},
		_event = {},
	}
	return setmetatable(t, timeline)
end

local singleton = timeline.new()

return singleton

--[[

-- test

local t = timeline.new()

t:play "test"

t:play {
	{ tick = 0, event = "test" },
	{ tick = 20, event = "again" },
	{ tick = 30, event = "cancel" },
}

local ev = {}

function ev:test(tid, ud)
	print "test"
end

function ev:cancel(tid, ud)
	self:stop(tid)
end

function ev:again(tid, ud)
	t:add(tid, 0, "test")
	t:add(tid, 20, "again")
end

local function f(t, tid, event, ud)
	ev[event](t, tid, ud)
end

for i = 1, 100 do
	t:update(f)
end

]]