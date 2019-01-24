local util = {}; util.__index = util

local function append_properties(properties, property_name, newproperties)
	local internal = properties.internal
	if internal == nil then
		internal = {}
		properties.internal = internal
	end

	local subproperties = internal[property_name]
	if subproperties == nil then
		subproperties = {}
		internal[property_name] = subproperties
	end	

	for k, v in pairs(newproperties) do
		subproperties[k] = v
	end
end

function util.append_uniform_properties(properties, uniform_properties)
	append_properties(properties, "uniforms", uniform_properties)
end

function util.append_texture_properties(properties, texture_properties)
	append_properties(properties, "textures", texture_properties)
end

return util