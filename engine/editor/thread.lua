local thread = require "thread"

local function createThread(name, code)
	if code == nil then
		code = name
		name = "<thread>"
	end
	thread.channel_produce "INITTHREAD"(arg)
	return thread.thread(([=[
--%s
%s]=]):format(name, code))
end

return {
	create = createThread,
	wait = thread.wait,
}
