local thread = require "bee.thread"
if thread.id ~= 0 then
    return
end

local socket = require "bee.socket"
local boot = require "ltask.bootstrap"
local lfs = require "bee.filesystem"
local vfs = require "vfs"

local repopath = _VFS_ROOT_
    and lfs.absolute(lfs.path(_VFS_ROOT_)):string()
    or lfs.absolute(lfs.path(arg[0])):remove_filename():string()

thread.newchannel "IOreq"

local s, c = socket.pair()
local io_req = thread.channel "IOreq"
io_req:push(repopath, s:detach())

vfs.iothread = boot.preinit [[
    -- IO thread
    local dbg = dofile "engine/debugger.lua"
    if dbg then
        dbg:event("setThreadName", "Thread: IO")
        --dbg:event "wait"
    end
    local fastio = require "fastio"
    local thread = require "bee.thread"
    local io_req = thread.channel "IOreq"
    assert(fastio.loadfile "engine/editor/io.lua")(io_req:bpop())
]]

vfs.initfunc("engine/firmware/init_thread.lua", {
	fd = c:detach(),
	editor = __ANT_EDITOR__,
})

package.path = package.path:gsub("[^;]+", function (s)
    if s:sub(1,1) ~= "/" then
        s = "/" .. s
    end
    return s
end)
