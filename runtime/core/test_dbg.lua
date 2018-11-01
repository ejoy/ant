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

local dbg = require 'debugger'
local dbgupdate = dbg.start_master()

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
