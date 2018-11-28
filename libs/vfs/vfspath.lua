-- a lua searcher for local vfs
-- must call with: 'dofile "libs/vfs/vfspath.lua"'

local lfs = require "lfs"
local root = ...
if root == "." then
	root = lfs.currentdir()
end

-- this mount paths used in this simple vfs and libs/vfs/vfs.lua
local _mounts = {
	["engine/assets"] = root .. "/assets",
	["engine/libs"] = root .. "/libs",
	["engine/clibs"] = root .. "/clibs",
	[""] = root,
}
-- another simple vfs interface, used before local vfs(in libs/vfs/vfs.lua) can be loaded using standard require
local vfs = {}
function vfs.realpath(filename)
	filename = filename:match "^/?(.-)/?$"	
	for mname, mpath in pairs(_mounts) do
		if filename == mname then
			return mpath
		end
		local n = #mname + 1
		if filename:sub(1,n) == mname .. '/' then
			return mpath .. "/" .. filename:sub(n+1)
		end
	end
	return root .. "/" .. filename
end

function vfs.isfile(filename)
	local rp = vfs.realpath(filename)
	return lfs.attributes(rp, "mode") == "file"
end

local function searchpath(name, spath, sep, rep)
	sep = sep or "."
	rep = rep or "/"	
	local errmsg = ""
	local newname = name:gsub("%" .. sep, rep)
	for p in spath:gmatch("[^;]+") do
		local newpath = p:gsub("%?", newname)		
		if vfs.isfile(newpath) then
			return newpath
		end
		errmsg = errmsg .. ("\n\tfile not found '%s'"):format(newpath)
	end
	return nil, errmsg
end

local nativeio_open = io.open

local function vfs_searcher_LUA(modname)
	local mod_filepath, serr = searchpath(modname, package.path)
	if mod_filepath == nil then
		return serr
	end

	local real_modfilepath = vfs.realpath(mod_filepath)
	if real_modfilepath == nil then
		error(string.format("not found file '%s' in vfs", real_modfilepath))
	end

	local f = nativeio_open(real_modfilepath, "r")
	if f == nil then
		error(string.format("open file failed:'%s'", real_modfilepath))
	end

	local c = f:read "a"
	local func, lerr = load(c, "@vfs://" .. mod_filepath)
	if lerr then
		error(string.format("load file '%s' failed: %s", mod_filepath, lerr))
	end
	return func, mod_filepath
end

package.searchers[2] = vfs_searcher_LUA
package.searchpath = searchpath

-- engine/clibs/?.lua for searching wrapper lua in c module
package.path = "?.lua;engine/libs/?.lua;engine/libs/?/?.lua;engine/clibs/?.lua" 

-- standrad require method to load "libs/vfs/vfs.lua"
local realvfs = require "vfs"
realvfs.mount(_mounts, root)

-- init local repo
local repopath = realvfs.repopath()
if not lfs.exist(repopath) then
	lfs.mkdir(repopath)
end
for i=0,0xff do
	local abspath = string.format("%s/%02x", repopath , i)
	if lfs.attributes(abspath, "mode") ~= "directory" then
		assert(lfs.mkdir(abspath))
	end
end