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
    rdebug.start [[
        package.path = "/pkg/ant.debugger/script/?.lua"
        function package.readfile(filename)
            local vfs = require 'vfs'
            local vpath = assert(package.searchpath(filename, package.path))
            local lpath = assert(vfs.realpath(vpath))
            local f = assert(io.open(lpath))
            local str = f:read 'a'
            f:close()
            return str
        end
        local directory = dofile "engine/directory.lua"
        local fs = require "bee.filesystem"
        local logpath = directory.app_path():string()
        require 'backend.bootstrap'. start(logpath, "4378")
    ]]
    return self
end

function dbg:attach()
    rdebug.start [[
        package.path = "/pkg/ant.debugger/script/?.lua"
        function package.readfile(filename)
            local vfs = require 'vfs'
            local vpath = assert(package.searchpath(filename, package.path))
            local lpath = assert(vfs.realpath(vpath))
            local f = assert(io.open(lpath))
            local str = f:read 'a'
            f:close()
            return str
        end
        local directory = dofile "engine/directory.lua"
        local fs = require "bee.filesystem"
        local logpath = directory.app_path():string()
        require 'backend.bootstrap'. attach(logpath)
    ]]
    return self
end

function dbg:event(...)
    rdebug.event(...)
    return self
end

debug.getregistry()["lua-debug"] = dbg

return dbg
