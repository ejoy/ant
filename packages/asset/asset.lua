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

local function require_ext(ext)
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

local function merge(a, b)
    for k, v in pairs(b) do
        if not a[k] then
            a[k] = v
        end
    end
end

function assetmgr.load_fx(fx, setting)
	setting = setting or {}
	local newfx = { setting = setting }
	local function check_resolve_path(p)
		if fx[p] then
			newfx[p] = absolute_path(fx[p])
		end
	end
	check_resolve_path "vs"
	check_resolve_path "fs"
	check_resolve_path "cs"
    if fx.setting then
        merge(setting, fx.setting)
    end
	return cr.load_fx(newfx)
end

assetmgr.edit = resource.edit
assetmgr.unload = resource.unload
assetmgr.reload = resource.reload

return assetmgr
