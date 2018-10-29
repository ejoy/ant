dofile "libs/init.lua"

--package.path = "runtime/core/firmware/?.lua;"..package.path

local reponame = assert((...), "Need repo name")

local fs = require "filesystem"
local thread = require "thread"

thread.thread [[
	-- thread for log
	dofile "libs/init.lua"

	local thread = require "thread"
	local err = thread.channel "errlog"

	while true do
		print("ERROR:" .. err:bpop())
	end
]]

local repopath = fs.personaldir() .. "/" .. reponame
local firmware = "runtime/core/firmware"

local boot = assert(loadfile(firmware .. "/bootstrap.lua"))

boot(firmware)

local vfs = require "vfs"	-- from boot

print("Repo:", repopath)
vfs.open(repopath)

local function list_dir(d, indent)
	local dir = vfs.list(d)
	for name,isdir in pairs(dir) do
		if isdir then
			print(string.format("%s%s/", (" "):rep(indent), name))
			list_dir(d .. "/" .. name, indent + 2)
		else
			print(string.format("%s%s", (" "):rep(indent), name))
		end
	end
end

list_dir("",0)


