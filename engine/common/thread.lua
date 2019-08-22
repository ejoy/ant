local thread = require "thread"

if not __ANT_RUNTIME__ then
	local function createThread(name, code)
		thread.thread(([=[
--%s
package.path = [[%s]]
package.cpath = [[%s]]
%s]=]):format(name, package.path, package.cpath, code)
		)
	end
	return {
		createThread = createThread,
	}
end

require 'runtime.vfs'
require 'runtime.log'

local function createThread(name, code)
	local vfs = require 'vfs'
	local init_thread = vfs.realpath('engine/firmware/init_thread.lua')
	thread.thread(([=[
	--%s
	__ANT_RUNTIME__ = %q
    package.searchers[3] = ...
	package.searchers[4] = nil
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
    createThread = createThread,
}
