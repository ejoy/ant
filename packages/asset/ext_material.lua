local assetutil = require "util"
local assetmgr 	= require "asset"
local fs 		= require "filesystem"
local bgfx		= require "bgfx"

local function find_subres_path(originpath, subrespath)
	if not subrespath:is_absolute() then
		local dir = originpath:parent_path()
		local fullpath = dir / subrespath
		if not fs.exists(fullpath) then
			fullpath = assetmgr.get_depiction_path(fullpath)
			if fullpath == nil or not fs.exists(fullpath) then
				fullpath = fs.path("/pkg") / originpath:package_name() / subrespath
			end
		end
		return fullpath
	end
	return subrespath
end

local function load_shader(originpath, shader)
	for k, v in pairs(shader)do
		assert(type(v) == "string")
		shader[k] = find_subres_path(originpath, fs.path(v))
	end
	
	return assetutil.load_shader_program(shader)
end

local function load_state(originpath, state)
	if type(state) == "string" then
		local s = asset.load(find_subres_path(originpath, state))
		assert(s.ref_path == nil)
		s.ref_path = state
		return s
	end

	assert(type(state) == "table")
	return state
end

local function load_properties(originpath, properties)
	local textures = properties.textures
	for _, tex in pairs(textures)do
		assert(type(tex.ref_path) == "string")
		tex.ref_path = find_subres_path(originpath, fs.path(tex.ref_path))
		assetmgr.load(tex.ref_path)
	end
	return properties
end

local function def_surface_type()
	return {
		lighting = "on",			-- "on"/"off"
		transparency = "opaticy",	-- "opaticy"/"transparent"
		shadow	= {
			cast = "on",			-- "on"/"off"
			receive = "on",			-- "on"/"off"
		},
		subsurface = "off",			-- "on"/"off"? maybe has other setting
	}
end

local function load_surface_type(_, surfacetype)
	if surfacetype == nil then
		return def_surface_type()
	end

	for k, v in pairs(def_surface_type()) do
		if surfacetype[k] == nil then
			surfacetype[k] = v
		end
	end
	return surfacetype
end

local function unload_shader(shader)
	
	for _, name in ipairs {"vs", "fs", "cs"} do
		local shaderpath = shader[name]
		if shaderpath then
			assert(type(shaderpath) == "userdata")
			local res = assetmgr.get_resource(shaderpath)
			assetmgr.unload(res, shaderpath)
			shader[name] = nil
		end
	end
end

return {
	loader = function(filename)
		local material = assetmgr.get_depiction(filename)
		return {
			shader 		= load_shader(filename, material.shader),
			state 		= load_state(filename, material.state),
			properties 	= load_properties(filename, material.properties),
			surface_type= load_surface_type(filename, material.surface),
		}
	end,
	unloader = function(res)
		local handle = res.handle
		unload_shader(handle.shader)
		handle.shader = nil

		if handle.state.ref_path then
			assetmgr.unload(handle.state, handle.state.ref_path)
			handle.state = nil
		end

		if handle.properties then
			local textures = handle.properties.textures
			for _, tex in pairs(textures) do
				assetmgr.unload(tex, tex.ref_path)
			end
			handle.properties = nil
		end

		handle.surface_type = nil
	end
}