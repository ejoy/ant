local texture_mgr	= require "texture_mgr"
local async			= require "async"
local sa			= require "system_attribs"	-- must require after 'texture_mgr.init()', system_attribs need default texture id

local assetmgr = {}

local function gen_cache()
	local cache_meta = {}
	local old_n = 0
	local new_n = 0
	local old = {}

	function cache_meta:__index(name)
		local v = old[name]
		if v then
			old[name] = nil
			old_n = old_n - 1
			self[name] = v
			return v
		end
	end

	function cache_meta:__newindex(name, v)
		new_n = new_n + 1
		rawset(self, name, v)
	end

	-- flush cache
	function cache_meta:__call()
		local ret
		local cap = new_n * 2 + old_n // 2
		local total = old_n + new_n - cap
		if total > 0 then
			ret = {}
			for i = 1, total do
				local k,v = next(old)
				ret[i] = v
				old[k] = nil
				old_n = old_n - 1
			end
		end
		for k,v in pairs(self) do
			old[k] = v
			self[k] = nil
			old_n = old_n + 1
		end
		new_n = 0
		return ret
	end

	return setmetatable({}, cache_meta)
end

local function require_ext(ext)
	return require("ext_" .. ext)
end

local EXTLIST = setmetatable({}, {
	__index = function(self, ext)
		local list = gen_cache(require_ext(ext))
		self[ext] = list
		return list
	end
})

local function get_cache(fullpath)
	local ext = fullpath:match "[^.]*$"
	return EXTLIST[ext], require_ext(ext)
end

function assetmgr.init()
	async.init()
	texture_mgr.init()

	local MA	  = import_package "ant.material".arena
	sa.init(texture_mgr, MA)
end

function assetmgr.load(fullpath, block)
	local FILELIST, api = get_cache(fullpath)
	local robj = FILELIST[fullpath]
	if not robj then
		robj = api.loader(fullpath, block)
		FILELIST[fullpath] = robj
	end
	return robj
end

function assetmgr.reload(fullpath, block)
	local FILELIST, api = get_cache(fullpath)
	local robj = FILELIST[fullpath]
	if robj then
		robj = api.reloader(fullpath, robj, block)
		FILELIST[fullpath] = robj
	end
	return robj
end

function assetmgr.flush()
	for ext, cache in pairs(EXTLIST) do
		local del = cache()	-- flush cache
		if del then
			local unload = require_ext(ext).unloader
			if unload then
				for _, v in ipairs(del) do
					unload(v)
				end
			end
		end
	end
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
assetmgr.set_atlas			= async.atlas_set
return assetmgr
