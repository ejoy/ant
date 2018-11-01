dofile "libs/init.lua"

local reponame = assert((...), "Need repo name")

local fs = require "filesystem"
local thread = require "thread"


local repopath = fs.personaldir() .. "/" .. reponame
local firmware = "runtime/core/firmware"

local boot = assert(loadfile(firmware .. "/bootstrap.lua"))

boot(firmware, "127.0.0.1", 2018)

local vfs = require "vfs"	-- from boot

print("Repo:", repopath)
vfs.open(repopath)

dofile 'runtime/core/init_thread.lua'


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

thread.thread [[
print(pcall(function()
	dofile 'runtime/core/init_thread.lua'

	local dbg = require 'debugger'
	local dbgupdate = dbg.start_worker()

	local thread = require "thread"
	local err = thread.channel "errlog"

	local function printLOG(ok, ...)
		if ok then
			print("ERROR:" .. ...)
		end
	end
	while true do
		dbgupdate()
		printLOG(err:pop())
	end
end))
]]

while true do
	dbgupdate()
end
