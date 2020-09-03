local thread = require "thread"

local function createThread(name, code)
	if code == nil then
		code = name
		name = "<thread>"
	end
	thread.channel_produce "INITTHREAD"(arg)
	return thread.thread(([=[
--%s
package.cpath = %q
%s]=]):format(name, package.cpath, code))
end

return {
	create = createThread,
	wait = thread.wait,
}
