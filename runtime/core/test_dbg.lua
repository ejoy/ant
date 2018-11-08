local reponame = assert((...), "Need repo name")

local fs = require "lfs"
local thread = require "thread"


local repopath = fs.personaldir() .. "/" .. reponame
local firmware = "runtime/core/firmware"

local boot = assert(loadfile(firmware .. "/bootstrap.lua"))

boot(firmware, "127.0.0.1", 2018)

local vfs = require "vfs"	-- from boot

print("Repo:", repopath)
vfs.open(repopath)

assert(loadfile('runtime/core/init_thread.lua'))(package.searchers[3])

thread.newchannel "DdgNet"
local io_req  = thread.channel "IOreq"
local dbg_net = thread.channel "DdgNet"
io_req:push("SUBSCIBE", "DdgNet", "DBG")
local dbg_io = {}
function dbg_io:event_in(f)
	self.fsend = f
end
function dbg_io:event_close(f)
    self.fclose = f
end
function dbg_io:update()
	local ok, cmd, msg = dbg_net:pop()
	if ok then
		self.fsend(msg)
	end
    return true
end
function dbg_io:send(data)
	io_req:push("SEND", "DBG", data)
end
function dbg_io:close()
    self.fclose()
end

local dbg = require 'debugger'
local dbgupdate = dbg.start_master(dbg_io)

local function createThread(name, code)
	thread.thread(([[
	--%s
	assert(loadfile('runtime/core/init_thread.lua'))(...)
%s]]):format(name, code)
		, package.searchers[3]
	)
end

createThread('errlog', [[
	local thread = require "thread"
	local err = thread.channel "errlog"
	while true do
		print("ERROR:" .. err:bpop())
	end
]])

createThread('debug', [[
	local dbg = require 'debugger'
	local dbgupdate = dbg.start_worker()
	local function test()
		local i = 0
		i = i + 1
	end
	while true do
		test()
		dbgupdate()
	end
]])

while true do
	dbgupdate()
end
