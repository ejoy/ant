local require = import and import(...) or require

local rawtable = require "rawtable"
local assetutil = require "asset.util"

return function(filename)
    local asset = require "asset"

    local material = assert(rawtable(filename))
    local material_info = {}
    local loaders = {
		state = function (t) return t end, 
		shader = assetutil.shader_loader,		
	}
	for k, v in pairs(material) do
		local loader = loaders[k]
        if loader then
            local t = type(v)
            if t == "string" then
                material_info[k] = asset.load(v)
			elseif t == "table" then
				material_info[k] = loader(v)
            end
        else
            material_info[k] = v
		end
	end
	
	if material_info.surface_type == nil then
		local ru = require "render.util"
		material_info.surface_type = ru.default_surface_type()
	end

    return material_info
end