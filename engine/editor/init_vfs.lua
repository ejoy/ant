local thread = require "bee.thread"
if thread.id ~= 0 then
    return
end

local boot = require "ltask.bootstrap"
local lfs = require "filesystem.local"
local vfs = require "vfs"

local repopath = _VFS_ROOT_
    and lfs.absolute(lfs.path(_VFS_ROOT_)):string()
    or lfs.absolute(lfs.path(arg[0])):remove_filename():string()

thread.newchannel "IOreq"
vfs.iothread = boot.preinit (([[
    -- IO thread
    local dbg = dofile "engine/debugger.lua"
    if dbg then
        dbg:event("setThreadName", "IO thread")
        dbg:event "wait"
    end
    local function loadfile(path)
        local f = io.open(path)
        if not f then
            return nil, path..':No such file or directory.'
        end
        local str = f:read 'a'
        f:close()
        return load(str, "@" .. path)
    end
    assert(loadfile "engine/editor/io.lua")(%q, %q)
]]):format(package.cpath, repopath))

vfs.initfunc "engine/firmware/init_thread.lua"
