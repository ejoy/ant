local assetutil = require "util"
local assetmgr 	= require "asset"
local fs 		= require "filesystem"
local bgfx		= require "bgfx"

local shader_stage_name = {
	"vs", "fs", "cs",
}

local function load_shader(shader)
	for ii=1, #shader_stage_name do
		local stagename = shader_stage_name[ii]
		local shaderpath = shader[stagename]
		if shaderpath then
			shader[stagename] = fs.path(shaderpath)
		end
	end
	
	return assetutil.load_shader_program(shader)
end

local function load_state(state)
	if type(state) == "string" then
		local filepath = fs.path(state)
		local s = assetmgr.load(filepath)
		if s.ref_path then
			assert(s.ref_path == filepath)
		else
			s.ref_path = filepath
		end
		
		return s
	end

	assert(type(state) == "table")
	return state
end

local function load_properties(properties)
	for _, tex in assetutil.each_texture(properties) do
		tex.ref_path = fs.path(tex.ref_path)
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

local function load_surface_type(surfacetype)
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
		local material = assetmgr.load_depiction(filename)
		return {
			shader 		= load_shader(material.shader),
			state 		= load_state(material.state),
			properties 	= load_properties(material.properties),
			surface_type= load_surface_type(material.surface_type),
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