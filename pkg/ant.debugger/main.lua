local function createBootstrap()
    return [=[
        package.path = "/pkg/ant.debugger/script/?.lua;engine/?.lua"
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
    vfs.send("REDIRECT_CHANNEL", "DBG", "DdgNet")
    vfs.send("SEND", "DEBUGGER_OPEN", "4378", "DBG")

    local bootstrap_lua = createBootstrap()
    local rdebug = require 'luadebug'
    rdebug.start(("assert(load(%q))(...)"):format(bootstrap_lua) .. [[
        local directory = require "directory"
        local fs = require "bee.filesystem"
        local logpath = directory.log_path():string()
        fs.create_directories(logpath)
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


local function protocol()
    local pkgpath = package.path
    package.path = "/pkg/ant.debugger/script/?.lua"
    local proto = require "script.common.protocol"
    package.path = pkgpath
    return proto
end

return {
    start = start,
    protocol = protocol,
}
