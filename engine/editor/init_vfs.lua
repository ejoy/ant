local thread = require "bee.thread"
if thread.id ~= 0 then
    return
end

local lfs = require "filesystem.local"
local repopath = _VFS_ROOT_
    and lfs.absolute(lfs.path(_VFS_ROOT_)):string()
    or lfs.absolute(lfs.path(arg[0])):remove_filename():string()

thread.thread([[
    -- Error Thread
    local thread = require "bee.thread"
    thread.setname "ant - Error thread"

    local err = thread.channel "errlog"
    while true do
        local msg = err:bpop()
        if msg == "EXIT" then
            break
        end
        print("ERROR:" .. msg)
    end
]])

thread.newchannel "IOreq"
thread.thread (([[
-- IO thread
print(xpcall(function()
    --local dbg = dofile "engine/debugger.lua"
    --if dbg then
    --    dbg:event("setThreadName", "IO thread")
    --    print "wait"
    --    dbg:event "wait"
    --end
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
end, debug.traceback))
]]):format(package.cpath, repopath))

local vfs = require "vfs"
vfs.initfunc "engine/firmware/init_thread.lua"
