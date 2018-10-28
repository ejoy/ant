--[[
	This test should run in ant directory :
		lua libs/vfs/test.lua
	It will create two project in "My documents" ,
	one is testrepo, another one is antproj.

	Check these two dir in your "My documents" dir.
]]

dofile("libs/init.lua")

--_G._DEBUG = true

local vfsrepo = require "vfs.repo"
local fs = require "filesystem"

local home = fs.personaldir() .. "/testrepo"
local cwd = fs.currentdir()

vfsrepo.init { home, libs = cwd .. "/libs", bin = cwd .."/bin" , ["libs/c"] = cwd .. "/clibs" }
print("init repo in ", home)
local repo = vfsrepo.new(home)
repo:index()
repo:touch "bin"
repo:touch_path "libs/vfs"
repo:build()

print("libs path = ", repo:realpath "libs")

local localrepo = require "vfs.local"
assert(localrepo.open(home))

local function list_repo()
	local function print_dir(path, ident)
		local filelist = localrepo.list(path)
		if filelist then
			for name, type in pairs(filelist) do
				if type == "dir" then
					print(string.format("%s%s/", (" "):rep(ident), name))
					print_dir(path .. "/" .. name, ident+2)
				else
					print(string.format("%s%s", (" "):rep(ident), name))
				end
			end
		end
	end
	print_dir("", 0)
end

list_repo()
