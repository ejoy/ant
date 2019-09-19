local platform = require "platform"
local thread = require "thread"
thread.newchannel "WNDMSG"
local channel = thread.channel_consume "WNDMSG"

local function create(run, w, h, name)
	local csearcher = package.searchers[3]
	if csearcher then
		if debug.getupvalue(csearcher, 1) then
			csearcher = nil
		end
	end
	thread.fork(run, ([[
--wndmsg
package.cpath = %q
local csearcher = ...
if csearcher then
	package.searchers[3] = csearcher
	package.searchers[4] = nil
end
local window = require "window"
local thread = require "thread"
local channel = thread.channel_produce "WNDMSG"
local function dispatch(...)
	channel:push(...)
end
window.create(dispatch, %d, %d, %q)
window.mainloop()
]]):format(package.cpath, w, h, name), csearcher)
end

local recvmsg

if platform.OS == "iOS" then
	function recvmsg()
		return true, channel:bpop()
	end
else
	function recvmsg()
		return channel:pop()
	end
end

return {
	create = create,
	recvmsg = recvmsg,
}
