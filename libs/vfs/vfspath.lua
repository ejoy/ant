-- a lua searcher for local vfs
-- must call with: 'dofile "libs/vfs/vfspath.lua"'

local lfs = require "lfs"
local enginepath = ...
local repopath = lfs.currentdir()
if enginepath == "." then
	enginepath = repopath
end

-- this mount paths used in this simple vfs and libs/vfs/vfs.lua
local mod_searchdirs = {	
	["engine/libs"] = enginepath .. "/libs",
	["engine/clibs"] = enginepath .. "/clibs",	
}

local function findpath(filename)
	filename = filename:match "^/?(.-)/?$"	
	for mname, mpath in pairs(mod_searchdirs) do
		if filename == mname then
			return mpath
		end
		local n = #mname + 1
		if filename:sub(1,n) == mname .. '/' then
			return mpath .. "/" .. filename:sub(n+1)
		end
	end
	return repopath .. "/" .. filename
end

local function isfile(filename)
	local rp = findpath(filename)
	return lfs.attributes(rp, "mode") == "file"
end

local function searchpath(name, spath, sep, rep)
	sep = sep or "."
	rep = rep or "/"	
	local errmsg = ""
	local newname = name:gsub("%" .. sep, rep)
	for p in spath:gmatch("[^;]+") do
		local newpath = p:gsub("%?", newname)		
		if isfile(newpath) then
			return newpath
		end
		errmsg = errmsg .. ("\n\tfile not found '%s'"):format(newpath)
	end
	return nil, errmsg
end

local nativeio_open = io.open

local function searcher_LUA(modname)
	local modpath, serr = searchpath(modname, package.path)
	if modpath == nil then
		return serr
	end

	local rmodpath = findpath(modpath)
	if rmodpath == nil then
		error(string.format("not found file '%s' in vfs", rmodpath))
	end

	local f = nativeio_open(rmodpath, "r")
	if f == nil then
		error(string.format("open file failed:'%s'", rmodpath))
	end

	local c = f:read "a"
	local func, lerr = load(c, "@vfs://" .. modpath)
	if lerr then
		error(string.format("load file '%s' failed: %s", modpath, lerr))
	end
	return func, modpath
end

package.searchers[2] = searcher_LUA
package.searchpath = searchpath

-- engine/clibs/?.lua for searching wrapper lua in c module
package.path = "?.lua;engine/libs/?.lua;engine/libs/?/?.lua;engine/clibs/?.lua" 

-- standrad require method to load "libs/vfs/vfs.lua"
local vfs = require "vfs"

if lfs.exist(repopath .. "/.mount") then
	if not vfs.open(repopath) then
		error(string.format("open repo failed, repo path : %s", repopath))
	end
else
	local mounts = {
		["engine/assets"] = enginepath .. "/assets",
		[""] = repopath,
	}
	for name, path in pairs(mod_searchdirs) do
		mounts[name] = path
	end
	vfs.mount(mounts, repopath)
end


-- init local repo
local repo_cachepath = vfs.repopath()
if not lfs.exist(repo_cachepath) then
	lfs.mkdir(repo_cachepath)
end
for i=0,0xff do
	local abspath = string.format("%s/%02x", repo_cachepath , i)
	if lfs.attributes(abspath, "mode") ~= "directory" then
		assert(lfs.mkdir(abspath))
	end
end