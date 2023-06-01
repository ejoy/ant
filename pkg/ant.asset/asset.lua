local resource		= require "resource"
local texture_mgr	= require "texture_mgr"
local async			= require "async"
local respath		= require "respath"

local assetmgr = {}

local function require_ext(ext)
	return require("ext_" .. ext)
end

local function initialize()
	local function loader(filename, data)
		local ext = filename:match "[^.]*$"
		local world = data
		local res
		respath.push(filename)
		res = require_ext(ext).loader(filename, world)
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
	async.init()
	texture_mgr.init()
	initialize()
end

assetmgr.edit = resource.edit
assetmgr.unload = resource.unload
assetmgr.reload = resource.reload
assetmgr.textures = texture_mgr.textures
assetmgr.invalid_texture = texture_mgr.invalid
assetmgr.load_fx = async.shader_create
assetmgr.compile = async.compile

return assetmgr
