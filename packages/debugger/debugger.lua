local function createBootstrap()
    require 'runtime.vfs'
    local vfs = require 'vfs'
    local init_thread = vfs.realpath('engine/firmware/init_thread.lua')
    return ([=[
        package.searchers[3] = ...
        package.searchers[4] = nil
        if debug.setcstacklimit then debug.setcstacklimit(1000) end
        local f, err = io.open(%q)
        if not f then
            error('engine/firmware/init_thread.lua:No such file or directory.')
        end
        local str = f:read 'a'
        f:close()
        assert(load(str, '@/engine/firmware/init_thread.lua'))()
        package.path = "pkg/ant.debugger/?.lua;engine/?.lua;engine/?/?.lua"
        require 'common.init_thread'
        local thread = require "remotedebug.thread"
        thread.bootstrap_lua = debug.getinfo(1, "S").source
        thread.bootstrap_c   = ...
    ]=]):format(init_thread)
end

local function start(wait)
    local thread = require 'thread'
    thread.newchannel "DdgNet"
    local io_req = thread.channel_produce "IOreq"
    io_req("SUBSCIBE", "DdgNet", "DBG")
    io_req("SEND", "DBG", "")

    local bootstrap_lua = createBootstrap()
    local rdebug = require 'remotedebug'
    rdebug.start(("assert(load(%q))(...)"):format(bootstrap_lua) .. [[
        require "backend.master" ("log/")
        require 'backend.worker'
    ]], package.searchers[3])
    local probe = rdebug.probe
    if wait then
        probe 'wait'
    end
    return function()
        probe 'update'
    end
end

return {
    start = start,
    math3d = require "math3d",
    protocol = require 'common.protocol',
}
