local texture_mgr	= require "texture_mgr"
local async			= require "async"
local sa			= require "system_attribs"	-- must require after 'texture_mgr.init()', system_attribs need default texture id

local assetmgr = {}

local FILELIST = {}

local function require_ext(ext)
	return require("ext_" .. ext)
end

function assetmgr.init()
	async.init()
	texture_mgr.init()

	local MA	  = import_package "ant.material".arena
	
	sa.init(texture_mgr, MA)
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

assetmgr.load_material		= async.material_create
assetmgr.unload_material	= async.material_destroy
assetmgr.material_check		= async.material_check
assetmgr.material_mark		= async.material_mark
assetmgr.material_unmark	= async.material_unmark
assetmgr.material_isvalid	= async.material_isvalid

assetmgr.textures 			= texture_mgr.textures
assetmgr.default_textureid	= texture_mgr.default_textureid
assetmgr.invalid_texture 	= texture_mgr.invalid
assetmgr.load_texture 		= async.texture_create_fast

return assetmgr
