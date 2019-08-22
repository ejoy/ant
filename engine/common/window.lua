local thread = require "thread"
thread.newchannel "WNDMSG"
local channel = thread.channel_consume "WNDMSG"

local createThread

if not __ANT_RUNTIME__ then
	function createThread(name, code)
		thread.thread(([=[
--%s
package.cpath = [[%s]]
%s]=]):format(name, package.cpath, code)
		)
	end
else
	function createThread(name, code)
		thread.thread(([=[
--%s
package.searchers[3] = ...
package.searchers[4] = nil
%s]=]):format(name, code)
			, package.searchers[3]
		)
	end
end

local function create(w, h, name)
	createThread('wndmsg', ([[
local window = require "window"
local thread = require "thread"
local channel = thread.channel_produce "WNDMSG"
local function dispatch(...)
	channel:push(...)
end
window.create(dispatch, %d, %d, %q)
window.mainloop()
]]):format(w, h, name))
end

local function recvmsg()
	return channel:pop()
end

return {
	create = create,
	recvmsg = recvmsg,
}
