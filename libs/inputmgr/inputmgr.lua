local require = import and import(...) or require

local im = {}

--[[ config example
im.queue {
	STATUS = {},
	X = function(x) return x end,
	key = "_,_,STATUS",
}
]]

local function convert(tbl, n, idx, f, v, ...)
	if n > 0 then
		tbl[idx] = f(idx, v)
		convert(tbl, n-1, idx+1, f, ...)
	end
end

local function init_message(q, fmt, cache)
	local args = {}
	local n = 0
	for v in fmt:gmatch "[%w_]+" do
		n = n + 1
		if v ~= "_" then
			local m = q._map[v]
			if m == nil then
				error ( v .. " is not defined in map")
			end
			args[n] = m
		end
	end
	local f = cache[fmt]
	if f == nil then
		local function conv(idx, c)
			local m = args[idx - 1]
			if m then
				return m[c]
			else
				return c
			end
		end
		f = function(tbl, msg, ...)
			tbl = tbl or {}
			tbl[1] = msg
			convert(tbl, n, 2, conv, ...)
			tbl.n = n + 1
			return tbl
		end
		cache[fmt] = f
	end
	return f
end

local function init_map(q, config)
	q._map = {}
	q._message = {}
	q._n = 0
	for k,v in pairs(config) do
		local t = type(v)
		if t == "table" then
			q._map[k] = v
		elseif t == "function" then
			q._map[k] = setmetatable({}, { __index = function(_, k) return v(k) end })
		elseif t == "string" then
			q._message[k] = v
		else
			error ( "Invalid config " .. k)
		end
	end
	local cache = {}
	for k,v in pairs(q._message) do
		q._message[k] = init_message(q, v, cache)
	end
end

local queue = {}
queue.__index = queue

function queue:__pairs()
	return queue.next, self, 0
end

function queue:push(msg, ...)
	local c = assert(self._message[msg], "Invalid message")
	local n = self._n + 1
	self._n = n
	self[n] = c(self[n], msg, ...)
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

local ctrl_cb = {
	"button",
	"motion",
	"keypress",
}

function queue:register_iup(ctrl)
	for _, cb in ipairs(ctrl_cb) do
		ctrl[cb .. "_cb"] = function(_, ...)
			self:push(cb, ...)
		end
	end
end

function im.queue(config)
	if type(config) == "string" then
		config = require(config)
	end
	local q = {}
	init_map(q, config)
	return setmetatable(q, queue)
end

return im
