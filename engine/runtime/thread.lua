local thread = require "thread"

require 'runtime.vfs'
require 'runtime.log'

local function createThread(name, code)
	if code == nil then
		code = name
		name = "<thread>"
	end
	local vfs = require 'vfs'
	local init_thread = vfs.realpath('engine/firmware/init_thread.lua')
	return thread.thread(([=[
	--%s
	__ANT_RUNTIME__ = %q
    package.searchers[3] = ...
	package.searchers[4] = nil
	debug.setcstacklimit(200)
	local function init_thread()
        local f, err = io.open(%q)
        if not f then
            error('engine/firmware/init_thread.lua:No such file or directory.')
        end
        local str = f:read 'a'
		f:close()
		assert(load(str, '@/engine/firmware/init_thread.lua'))()
	end
	init_thread()
	package.path = [[%s]]
    require 'runtime.vfs'
	require 'runtime.log'
%s]=]):format(name, __ANT_RUNTIME__, init_thread, package.path, code)
		, package.searchers[3]
	)
end

return {
	create = createThread,
	wait = thread.wait,
}
