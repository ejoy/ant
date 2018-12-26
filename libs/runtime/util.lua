local thread = require "thread"
require 'runtime.vfs'
require 'runtime.log'

local function createThread(name, code)
	local vfs = require 'vfs'
	local init_thread = vfs.realpath('firmware/init_thread.lua')
	thread.thread(([=[
	--%s
    package.searchers[3] = ...
	package.searchers[4] = nil
	local function init_thread()
        local f, err = io.open(%q)
        if not f then
            error('firmware/init_thread.lua:No such file or directory.')
        end
        local str = f:read 'a'
		f:close()
		assert(load(str, 'vfs://firmware/init_thread.lua'))()
	end
	init_thread()
	package.path = [[%s]]
    require 'runtime.vfs'
	require 'runtime.vfsio'
	require 'runtime.log'
%s]=]):format(name, init_thread, package.path, code)
		, package.searchers[3]
	)
end

return {
    createThread = createThread,
}
