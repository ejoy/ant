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

local shader_stage_name = {
	"vs", "fs", "cs",
}

local function load_shader(originpath, shader)
	for ii=1, #shader_stage_name do
		local stagename = shader_stage_name[ii]
		local shaderpath = shader[stagename]
		if shaderpath then
			shader[stagename] = find_subres_path(originpath, fs.path(shaderpath))
		end
	end
	
	return assetutil.load_shader_program(shader)
end

local function load_state(originpath, state)
	if type(state) == "string" then
		local fullpath = find_subres_path(originpath, fs.path(state))
		local s = assetmgr.load(fullpath)
		if s.ref_path then
			assert(s.ref_path == fullpath)
		else
			s.ref_path = fullpath
		end
		
		return s
	end

	assert(type(state) == "table")
	return state
end

local function load_properties(originpath, properties)
	for _, tex in assetutil.each_texture(properties) do
		tex.ref_path = find_subres_path(originpath, fs.path(tex.ref_path))
	end
	return assetutil.load_material_properties(properties)
end

local function def_surface_type()
	return {
		lighting = "on",			-- "on"/"off"
		transparency = "opaticy",	-- "opaticy"/"translucent"
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

return {
	loader = function(filename)
		local material = assetmgr.get_depiction(filename)
		return {
			shader 		= load_shader(filename, material.shader),
			state 		= load_state(filename, material.state),
			properties 	= load_properties(filename, material.properties),
			surface_type= load_surface_type(filename, material.surface_type),
		}
	end,
	unloader = function(res)
		bgfx.destroy(res.shader.prog)
		res.shader = nil
		res.state = nil
		res.properties = nil
		res.surface_type = nil
	end
}