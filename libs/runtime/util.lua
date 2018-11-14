local thread = require "thread"

local function createThread(name, code)
	thread.thread(([=[
	--%s
    package.searchers[3] = ...
    package.searchers[4] = nil
	dofile 'firmware/init_thread.lua'
	package.path = [[%s]]
	require 'runtime.vfs'
%s]=]):format(name, package.path, code)
		, package.searchers[3]
	)
end

return {
    createThread = createThread,
}
