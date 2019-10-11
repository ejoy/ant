local assetutil = require "util"
local assetmgr 	= require "asset"
local fs 		= require "filesystem"
local bgfx		= require "bgfx"

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

local function load_fx(fx)
	return assetmgr.load(fs.path(fx))
end

return {
	loader = function(filename)
		local material = assetmgr.load_depiction(filename)
		return {
			fx			= load_fx(material.fx),
			state 		= load_state(material.state),
			properties 	= load_properties(material.properties),
		}
	end,
	unloader = function(res)
		bgfx.destroy(res.fx.shader.prog)
		res.fx 			= nil
		res.state 		= nil
		res.properties 	= nil
	end
}