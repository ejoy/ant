local thread = require "bee.thread"
local socket = require "bee.socket"
local boot = require "ltask.bootstrap"
local lfs = require "bee.filesystem"
local vfs = require "vfs"

local repopath = lfs.absolute(lfs.path(arg[0])):remove_filename():string()

thread.newchannel "IOreq"

local s, c = socket.pair()
local io_req = thread.channel "IOreq"

io_req:push {
    repopath = repopath,
    fd = s:detach(),
    editor = __ANT_EDITOR__,
}

vfs.iothread = boot.preinit [[
-- IO thread
assert(loadfile "/engine/console/io.lua")()
]]

vfs.initfunc("/engine/firmware/init_thread.lua", {
    fd = c:detach(),
    editor = __ANT_EDITOR__,
})
