local assetmgr 	= require "asset"
local fs 		= require "filesystem"
local bgfx		= require "bgfx"

local function load_state(state)
	return bgfx.make_state(type(state) == "string" and
		assetmgr.get_resource(fs.path(state)) or
		state)
end

local function load_fx(fx)
	return assetmgr.load(fx)
end

local function load_properties(properties)
	if properties then
		local textures = properties.textures
		if textures then
			for _, tex in pairs(textures) do
				tex.texture = assetmgr.load(tex.texture)
			end
		end
	end

	return properties
end

return {
	loader = function(filename)
		if type(filename) == "string" then
			filename = fs.path(filename)
		end
		local material = assetmgr.load_depiction(filename)
		return {
			fx			= load_fx(material.fx),
			state 		= load_state(material.state),
			properties 	= load_properties(material.properties),
		}, 0
	end,
	unloader = function(res)
		bgfx.destroy(res.fx.shader.prog)
		res.fx 			= nil
		res.state 		= nil
		res.properties 	= nil
	end
}
