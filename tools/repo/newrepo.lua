dofile "libs/init.lua"

local arg_num = select('#', ...)

local reponame = select(1, ...)
local iseditor = arg_num >= 2 and select(2, ...) == "editor" or false

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

if iseditor then
	print("editor mode")
	local launch_filepath = repopath .. "\\launch.bat"

	local launch_file_template = [[
@echo off
SET ANTGE=%s
"%s\bin\iup.exe" "%s\main.lua"
]]

	local function slash_to_backslash(s)
		return s:gsub('/', '\\')
	end
	local f = io.open(launch_filepath, "wb")
	local normalize_enginepath = slash_to_backslash(enginepath)
	f:write(string.format(launch_file_template, normalize_enginepath, normalize_enginepath, slash_to_backslash(repopath)))
	f:close()

	local function cp_main_template()
		local dst_main_template_filepath = repopath .. "/main.lua"
		local src_main_template_filepath = "tools/repo/main_template.lua"
	
		local template_f = io.open(src_main_template_filepath, "rb")		
		local content = template_f:read("a")
		template_f:close()

		local dst_template_f = io.open(dst_main_template_filepath, "wb")
		dst_template_f:write(content)
		dst_template_f:close()
	end

	cp_main_template()
end










