local thread = require "thread"

local thd = thread.thread [=[
    package.path = "engine/?.lua"
    require "bootstrap"
]=]

local function createThread(name, code)
	if code == nil then
		code = name
		name = "<thread>"
	end
	thread.channel_produce "INITTHREAD"(arg)
	return thread.thread(([=[
--%s
package.path = "engine/?.lua"
require "bootstrap"
%s]=]):format(name, code))
end

return {
	create = createThread,
	wait = thread.wait,
}
