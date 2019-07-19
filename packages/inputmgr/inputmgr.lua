local im = {}

--[[ config example
im.queue {
	STATUS = {},
	X = function(x) return x end,
	key = "_,_,STATUS",
}
]]

local queue = {}
queue.__index = queue

function queue:__pairs()
	return queue.next, self, 0
end

function queue:push(msg, ...)
	local n = self._n + 1
	self._n = n
	self[n] = {msg, ...}
end

function queue:next(idx)
	if idx >= self._n then
		self._n = 0
		return
	end
	idx = idx + 1
	local msg = self[idx]
	return idx, table.unpack(msg, 1, msg.n)
end

function queue:clear()
	self._n = 0
end

function im.queue()
	return setmetatable({_n = 0}, queue)
end

local mouse_what = {
	'LEFT', 'RIGHT', 'MIDDLE'
}

local mouse_state = {
	'DOWN', 'MOVE', 'UP'
}

function im.translate_mouse_button(what)
	return mouse_what[what] or "UNKNOWN"
end

function im.translate_mouse_state(state)
	return mouse_state[state] or "UNKNOWN"
end

function im.translate_key_state(state)
	return {
		CTRL 	= (state & 0x01) ~= 0,
		ALT 	= (state & 0x02) ~= 0,
		SHIFT 	= (state & 0x04) ~= 0,
		SYS 	= (state & 0x08) ~= 0,
	}
end

return im