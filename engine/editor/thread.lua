local thread = require "thread"

if thread.id == 0 then
	thread.newchannel "IOreq"
	thread.newchannel "INITTHREAD"
	local registry = debug.getregistry()
	local debugger = registry["lua-debug"]
	if debugger then
		registry.DEBUG_ATTACH = ([[
			local path = %q
			local f = assert(io.open(path.."/script/debugger.lua"))
			local str = f:read "a"
			f:close()
			assert(load(str, "=(BOOTSTRAP)"))(path)
			:start {latest=true,address="<Not Needed>"} 
			:event "wait"
		]]):format(debugger.root)
	end
end

local function bootstrap(name, code)
	if code == nil then
		code = name
		name = "<thread>"
	end
	thread.channel_produce "INITTHREAD"(arg, debug.getregistry().DEBUG_ATTACH)
	return ([=[
--%s
package.path = %q
package.cpath = %q
local thread = require "thread"
local attach
arg, attach = thread.channel_consume "INITTHREAD"()
if attach then
	debug.getregistry().DEBUG_ATTACH = attach
	assert(load(attach, "=(BOOTSTRAP)"))()
end
return assert(load(%q))()]=]):format(name, package.path, package.cpath, code)
end

local function createThread(name, code)
	return thread.thread(bootstrap(name, code))
end

return {
	create = createThread,
	bootstrap = bootstrap,
	wait = thread.wait,
}
