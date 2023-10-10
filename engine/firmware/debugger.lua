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

local rdebug = require "luadebug"

local dbg = {}

function dbg:start()
    local vfs = require "vfs"
    local thread = require "bee.thread"
    thread.newchannel "DdgNet"
    vfs.send("REDIRECT_CHANNEL", "DBG", "DdgNet")
    vfs.send("SEND", "DEBUGGER_OPEN", "4378", "DBG")
    if not os.getenv "LUA_DEBUG_PATH" then
        local path = vfs.realpath "/engine/firmware/debugger.lua"
        rdebug.setenv("LUA_DEBUG_PATH", path)
    end
    local bootstrap_lua = createBootstrap()
    rdebug.start(("assert(load(%q))(...)"):format(bootstrap_lua) .. [[
        local directory = require "directory"
        local fs = require "bee.filesystem"
        local logpath = directory.log_path():string()
        fs.create_directories(logpath)
        local log = require 'common.log'
        log.file = logpath..'/worker.log'
        require 'backend.master' .init(logpath, "4378")
        require 'backend.worker'
    ]])
    return self
end

function dbg:attach()
    local bootstrap_lua = createBootstrap()
    rdebug.start(("assert(load(%q))(...)"):format(bootstrap_lua) .. [[
        if require 'backend.master' .has() then
            local directory = require "directory"
            local fs = require "bee.filesystem"
            local logpath = directory.log_path():string()
            local log = require 'common.log'
            log.file = logpath..'/worker.log'
            require 'backend.worker'
        end
    ]])
    return self
end

function dbg:event(...)
    rdebug.event(...)
    return self
end

debug.getregistry()["lua-debug"] = dbg

return dbg
