dofile "libs/editor.lua"

--package.path = "runtime/core/firmware/?.lua;"..package.path

local reponame = assert((...), "Need repo name")

local thread = require "thread"
local fs = require "filesystem.local"

thread.thread [[
	-- thread for log
	dofile "libs/editor.lua"

	local thread = require "thread"
	local err = thread.channel_consume "errlog"

	while true do
		print("ERROR:" .. err())
	end
]]

do
	local err = thread.channel_produce "errlog"
	function _G.print(...)
		local t = table.pack( "[Main]", ... )
		for i= 1, t.n do
			t[i] = tostring(t[i])
		end
		local str = table.concat( t , "\t" )
		err:push(str)
	end
end

local repopath = fs.mydocs_path() .. "/" .. reponame
local firmware = "runtime/core/firmware"

local boot = assert(loadfile(firmware .. "/bootstrap.lua"))

boot(firmware, "127.0.0.1", 2018)

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


