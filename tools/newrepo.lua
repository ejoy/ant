dofile "libs/init.lua"

local reponame = ...

local repo = require "vfs.repo"
local fs = require "filesystem"

local enginepath = os.getenv "ANTGE" or fs.currentdir()
local homepath = fs.personaldir()

print ("Ant engine path :", enginepath)
print ("Home path :", homepath)
if reponame == nil then
	error ("Need a project name")
end
print ("Project name :",reponame)

local mount = {
	["engine/libs"] = enginepath .. "/libs",
	["engine/assets"] = enginepath .. "/assets",
	["firmware"] = enginepath .. "/runtime/core/firmware",
}

for k,v in pairs(mount) do
	print("Mount", k, v)
end

local repopath = homepath .. "/" .. reponame

local function isdir(filepath)
	return fs.attributes(filepath, "mode") == "directory"
end

if not isdir(repopath) then
	if not fs.mkdir(repopath) then
		error("Can't mkdir "  .. repopath)
	end
end

local engine_mountpoint = repopath .. "/engine"
if not isdir(engine_mountpoint) then
	print("Mkdir ", engine_mountpoint)
	assert(fs.mkdir(engine_mountpoint))
end

mount[1] = repopath

print("Init repo in", repopath)
repo.init(mount)













