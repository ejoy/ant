local function createBootstrap()
    return [=[
        package.path = "/pkg/ant.debugger/?.lua;engine/?.lua;engine/?/?.lua"
        function package.readfile(filename)
            local vfs = require 'vfs'
            local vpath = assert(package.searchpath(filename, package.path))
            local lpath = assert(vfs.realpath(vpath))
            local f = assert(io.open(lpath))
            local str = f:read 'a'
            f:close()
            return str
        end
        local thread = require "bee.thread"
        thread.bootstrap_lua = debug.getinfo(1, "S").source
    ]=]
end

local function start(wait)
    local vfs = require "vfs"
    local thread = require "bee.thread"
    thread.newchannel "DdgNet"
    vfs.send("SUBSCIBE", "DdgNet", "DBG")
    vfs.send("SEND", "DBG", "")

    local bootstrap_lua = createBootstrap()
    local rdebug = require 'remotedebug'
    rdebug.start(("assert(load(%q))(...)"):format(bootstrap_lua) .. [[
        local logpath = "log/"
        local log = require 'common.log'
        log.file = logpath..'/worker.log'
        require 'backend.master' .init(logpath)
        require 'backend.worker'
    ]])
    local event = rdebug.event
    if wait then
        event 'wait'
    end
end

return {
    start = start,
    math3d = require "math3d",
    protocol = require 'common.protocol',
}
