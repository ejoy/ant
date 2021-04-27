local cr = import_package "ant.compile_resource"

local resource = require "resource"

local assetmgr = {}

local CURPATH = {}
local function push_currentpath(path)
	CURPATH[#CURPATH+1] = path:match "^(.-)[^/|]*$"
end
local function pop_currentpath()
	CURPATH[#CURPATH] = nil
end
local function absolute_path(path)
	local base = CURPATH[#CURPATH]
	if path:sub(1,1) == "/" or not base then
		return path
	end
	return base .. (path:match "^%./(.+)$" or path)
end

local extmapper = {
	bmp = "image", png = "image", dds = "image"
}

local function require_ext(ext)
	ext = extmapper[ext] or ext
	return require("ext_" .. ext)
end

local initialized = false
local function initialize()
	if initialized then
		return
	end
	initialized = true
	local function loader(filename, data)
		local ext = filename:match "[^.]*$"
		local world = data
		local res
		push_currentpath(filename)
		res = require_ext(ext).loader(filename, world)
		pop_currentpath()
		return res
	end
	local function unloader(filename, data, res)
		local ext = filename:match "[^.]*$"
		local world = data
		require_ext(ext).unloader(res, world)
	end
	resource.register(loader, unloader)
end

function assetmgr.resource(path, world)
	initialize()
	local fullpath = absolute_path(path)
	resource.load(fullpath, world, true)
	return resource.proxy(fullpath)
end

function assetmgr.load_fx(fx, setting)
	local function check_resolve_path(fx, p)
		if fx[p] then
			fx[p] = absolute_path(fx[p])
		end
	end
	check_resolve_path(fx, "vs")
	check_resolve_path(fx, "fs")
	check_resolve_path(fx, "cs")
	return cr.compile_fx(fx, setting)
end

assetmgr.edit = resource.edit
assetmgr.unload = resource.unload
assetmgr.reload = resource.reload

return assetmgr
