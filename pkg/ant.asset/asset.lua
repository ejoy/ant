local resource		= require "resource"
local texture_mgr	= require "texture_mgr"
local async			= require "async"
local respath		= require "respath"

local assetmgr = {}

local function require_ext(ext)
	return require("ext_" .. ext)
end

local function initialize()
	local function loader(filename)
		local ext = filename:match "[^.]*$"
		local res
		respath.push(filename)
		res = require_ext(ext).loader(filename)
		respath.pop()
		return res
	end
	local function reloader(filename, res)
		local ext = filename:match "[^.]*$"
		respath.push(filename)
		res = require_ext(ext).reloader(filename, res)
		respath.pop()
		return res
	end
	local function unloader(filename, res)
		local ext = filename:match "[^.]*$"
		require_ext(ext).unloader(res)
	end
	resource.register(loader, reloader, unloader)
end

function assetmgr.resource(path)
	local fullpath = respath.absolute_path(path)
	resource.load(fullpath, true)
	return resource.proxy(fullpath)
end

function assetmgr.reload(path)
	local fullpath = respath.absolute_path(path)
	resource.reload(fullpath)
	return resource.proxy(fullpath)
end

function assetmgr.init()
	async.init()
	texture_mgr.init()
	initialize()
end

assetmgr.edit = resource.edit
assetmgr.unload = resource.unload
assetmgr.textures = texture_mgr.textures
assetmgr.invalid_texture = texture_mgr.invalid
assetmgr.load_fx = async.shader_create
assetmgr.compile = async.compile

return assetmgr
