local thread = require "thread"

if thread.id == 0 then
	thread.newchannel "INITTHREAD"
	local registry = debug.getregistry()
	local debugger = registry["lua-debug"]
	if debugger then
		registry.DEBUG_ATTACH = debugger.attach_thread
	end
end

local function createThread(name, code)
	if code == nil then
		code = name
		name = "<thread>"
	end
	thread.channel_produce "INITTHREAD"(arg, debug.getregistry().DEBUG_ATTACH)
	return thread.thread(([=[
--%s
package.cpath = %q
local thread = require "thread"
local attach
arg, attach = thread.channel_consume "INITTHREAD"()
if attach then
	debug.getregistry().DEBUG_ATTACH = attach
	assert(load(attach, "=(BOOTSTRAP)"))()
end
%s]=]):format(name, package.cpath, code))
end

return {
	create = createThread,
	wait = thread.wait,
}
