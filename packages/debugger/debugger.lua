local function start_hook()
    local pm = require 'antpm'
    local rdebug = require 'remotedebug'
    local event = rdebug.probe

    local function eventwp(name, ...)
        local r
        event(name)
        return r
    end

    local _print = print
    pm.setglobal('print', function (...)
        if not eventwp('print', ...) then
            _print(...)
        end
    end)
    
    local io_output = debug.getregistry()._IO_output
    local mt = debug.getmetatable(io_output)
    local f_write = mt.write
    function mt.write(f, ...)
        if not eventwp('iowrite', ...) then
            return f_write(f, ...)
        end
        return f
    end

    local io_write = io.write
    function io.write(...)
        if not eventwp('iowrite', ...) then
            return io_write(...)
        end
        return io_output
    end
end

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
    local event = rdebug.probe
    start_hook()
    rdebug.start(bootstrap(), package.searchers[3])
    if wait then
        event 'wait_client'
    end
    return function()
        event 'update'
    end
end

return {
    start_master = start_master,
    start_worker = start_worker,
    math3d = require "math3d",
}
