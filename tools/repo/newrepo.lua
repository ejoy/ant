--[[
	cd to ant path, run:
	clibs/lua.exe tools/repo/newrepo.lua *projname* [*editor*]

	editor is optional
]]

dofile "libs/init.lua"

local reponame = select(1, ...)

local repo = require "vfs.repo"
local fs = require "filesystem"
local util = require "filesystem.util"

local ANTGE = os.getenv "ANTGE"
local enginepath = ANTGE and fs.path(ANTGE) or fs.current_path()
local homepath = fs.mydocs_path()

print ("Ant engine path :", enginepath)
print ("Home path :", homepath)
if reponame == nil then
	error ("Need a project name")
end
print ("Project name :",reponame)

local mount = {
	["engine/libs"] = enginepath / "libs",
	["engine/assets"] = enginepath / "assets",
	["firmware"] = enginepath / "runtime" / "core" / "firmware",
}

local repopath = homepath / reponame

if not fs.is_directory(repopath) then
	if not fs.create_directories(repopath) then
		error("Can't mkdir ", repopath)
	end
end

local engine_mountpoint = repopath / "engine"
if not fs.is_directory(engine_mountpoint) then
	print("Mkdir ", engine_mountpoint)
	assert(fs.create_directories(engine_mountpoint))
end

mount[1] = repopath

print("Init repo in", repopath)
repo.init(mount)
