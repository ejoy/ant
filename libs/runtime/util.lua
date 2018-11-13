local thread = require "thread"

local function createThread(name, code)
	thread.thread(([[
	--%s
    package.searchers[3] = ...
    package.searchers[4] = nil
	dofile 'firmware/init_thread.lua'
%s]]):format(name, code)
		, package.searchers[3]
	)
end

return {
    createThread = createThread,
}
