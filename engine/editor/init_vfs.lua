local thread = require "thread"
if thread.id ~= 0 then
    return
end

local lfs = require "filesystem.local"
local repopath = lfs.absolute(lfs.path(arg[0])):remove_filename():string()

thread.newchannel "IOreq"
thread.thread (([[
-- IO thread
local dbg = dofile "engine/debugger.lua"
if dbg then
    dbg:event("setThreadName", "IO")
    dbg:event "wait"
end
assert(loadfile "engine/editor/io.lua")(%q, %q)
]]):format(package.cpath, repopath))

local vfs = require "vfs"
vfs.initfunc "engine/firmware/init_thread.lua"
