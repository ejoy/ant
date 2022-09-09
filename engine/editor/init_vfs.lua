local thread = require "bee.thread"
if thread.id ~= 0 then
    return
end

local socket = require "bee.socket"
local boot = require "ltask.bootstrap"
local lfs = require "filesystem.local"
local vfs = require "vfs"

local repopath = _VFS_ROOT_
    and lfs.absolute(lfs.path(_VFS_ROOT_)):string()
    or lfs.absolute(lfs.path(arg[0])):remove_filename():string()

thread.newchannel "IOreq"

local s, c = socket.pair()
local io_req = thread.channel "IOreq"
io_req:push(package.cpath, repopath, socket.dump(s))

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
    local thread = require "bee.thread"
    local io_req = thread.channel "IOreq"
    assert(loadfile "engine/editor/io.lua")(io_req:bpop())
]]):format(package.cpath, repopath))

vfs.initfunc("engine/firmware/init_thread.lua", socket.dump(c))
