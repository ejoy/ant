local texture_mgr = require "texture_mgr"
local async       = require "async"

local assetmgr = {}

local FILELIST = {}

local function require_ext(ext)
	return require("ext_" .. ext)
end

function assetmgr.init()
	async.init()
	texture_mgr.init()
end

function assetmgr.load(fullpath)
	local robj = FILELIST[fullpath]
	if not robj then
		local ext = fullpath:match "[^.]*$"
		robj = require_ext(ext).loader(fullpath)
		FILELIST[fullpath] = robj
	end
	return robj
end

function assetmgr.unload(fullpath)
	local robj = FILELIST[fullpath]
	if robj == nil then
		return
	end
	local ext = fullpath:match "[^.]*$"
	require_ext(ext).unloader(robj)
	FILELIST[fullpath] = nil
end

function assetmgr.reload(fullpath)
	local robj = FILELIST[fullpath]
	if robj then
		local ext = fullpath:match "[^.]*$"
		robj = require_ext(ext).reloader(fullpath, robj)
		FILELIST[fullpath] = robj
	end
	return robj
end

assetmgr.resource = assetmgr.load
assetmgr.textures = texture_mgr.textures
assetmgr.invalid_texture = texture_mgr.invalid
assetmgr.compile = async.compile
assetmgr.load_shader = async.shader_create
assetmgr.load_texture = async.texture_create_fast

return assetmgr
