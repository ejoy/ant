local function start_master(io)
    local master = require 'backend.master.mgr'
    if master.init(io) then
        return master.update
    end
end

local function bootstrap()
    require 'runtime.vfs'
    local vfs = require 'vfs'
    local init_thread = vfs.realpath('engine/firmware/init_thread.lua')
    return ([=[
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
        package.readfile = function(filename)
            local vfs = require 'vfs.simplefs'
            local fullpath = assert(package.searchpath(filename, package.path))
            local fullpath = assert(vfs.realpath(fullpath))
            local f = assert(io.open(fullpath))
            local str = f:read 'a'
            f:close()
            return str
        end
        require 'runtime.vfs'
        require 'backend.worker'
    ]=]):format(init_thread, "engine/?.lua;engine/?/?.lua;pkg/ant.debugger/?.lua")
end

local function start_worker(wait)
    local rdebug = require 'remotedebug'
    local probe = rdebug.probe
    rdebug.start(bootstrap(), package.searchers[3])
    if wait then
        probe 'wait'
    end
    return function()
        probe 'update'
    end
end

return {
    start_master = start_master,
    start_worker = start_worker,
    math3d = require "math3d",
}
