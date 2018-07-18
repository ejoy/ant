
dofile "libs/init.lua"
local rhwi = require "render.hardware_interface"
local scene = require "scene.util"

local msg_queue = { 
	num = 0,
	messages = {
		button = function (btn, press, x, y, status)
			return {n = 5, assert(btn), assert(press), assert(x), assert(y), status}
		end,
		motion = function (x, y, status)
			return {n = 3, assert(x), assert(y), assert(status)}
		end
	},
}; 
msg_queue.__index = msg_queue

function msg_queue:clear()
	self.num = 0
end

function msg_queue:__pairs()
	return msg_queue.next, self, 0
end

function msg_queue:push(msg, ...)
	local c = assert(self.messages[msg], "Invalid message")
	local num = self.num + 1
	self.num = num
	self[num] = c(self[num], msg, ...)
end

function msg_queue:next(idx)
	if idx >= self.num then
		self.num = 0
		return
	end
	idx = idx + 1
	local msg = self[idx]
	return idx, table.unpack(msg, 1, msg.n)
end

local currentworld
function init(nativewnd, fbw, fbh)
	rhwi.init(nativewnd, fbw, fbh)	
	currentworld = scene.start_new_world(msg_queue, fbw, fbh, "test_world.module")
end

function input(msg, ...)
	msg_queue:push(msg, ...)
end

function mainloop()
	currentworld.update()
end