local function start_master(io)
    local master = require 'debugger.backend.master'
    if master.init(io) then
        return master.update
    end
end

local function bootstrap()
    require 'runtime.vfs'
    local vfs = require 'vfs'
    local init_thread = vfs.realpath('firmware/init_thread.lua')
    return ([=[
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
        require 'debugger.backend.worker'
    ]=]):format(init_thread, "engine/libs/?.lua;engine/packages/?.lua")
end

local function start_worker(wait)
    local rdebug = require 'remotedebug'
    local probe = rdebug.probe
    rdebug.start(bootstrap(), package.searchers[3])
    if wait then
        probe 'wait_client'
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
