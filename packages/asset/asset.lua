local resource = require "resource"
local url = import_package "ant.url"
local texture_mgr = require "texture_mgr"
local efkobj		= require "efkobj"

local respath = require "respath"

local assetmgr = {}

local function require_ext(ext)
	return require("ext_" .. ext)
end

local function initialize()
	local function loader(fileurl, data)
		local filename = url.parse(fileurl)
		local ext = filename:match "[^.]*$"
		local world = data
		local res
		respath.push(filename)
		res = require_ext(ext).loader(fileurl, world)
		respath.pop()
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
	local fullpath = respath.absolute_path(path)
	resource.load(fullpath, world, true)
	return resource.proxy(fullpath)
end

function assetmgr.init()
	texture_mgr.init()
	initialize()
end

function assetmgr.set_efkobj(efkctx)
	efkobj.ctx = efkctx
end

assetmgr.edit = resource.edit
assetmgr.unload = resource.unload
assetmgr.reload = resource.reload
assetmgr.textures = texture_mgr.textures
assetmgr.load_fx = require "load_fx"

return assetmgr
