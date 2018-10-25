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
local localrepo = require "vfs.local"

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

local function list_repo(repo)
	local root = repo:root()
	local function print_dir(hash, ident)
		local filelist = repo:dir(hash)
		if filelist then
			for name, hash in pairs(filelist.dir) do
				print(string.format("%s%s/", (" "):rep(ident), name))
				print_dir(hash, ident+2)
			end
			for name, hash in pairs(filelist.file) do
				print(string.format("%s%s", (" "):rep(ident), name))
			end
		end
	end
	print_dir(root, 0)
end

--list_repo(repo)

localrepo.init("antproj")
assert(localrepo.open "antproj")
localrepo.build()

local repo = {}

function repo:root()
	return localrepo.hash ''
end

function repo:dir(hash)
	return localrepo.list(hash)
end


list_repo(repo)


