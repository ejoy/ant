local rawtable = require "common.rawtable"
local assetutil = require "asset.util"
local assetmgr = require "asset"
local fs = require "filesystem"
local ru = require "render.util"

local loaders = {
	state = function (t) return t end, 
	shader = function (t)
		return assetutil.shader_loader(t)
	end
}

return function(filepath)
	local fn = assetmgr.find_depiction_path(filepath)	
	local material = assert(rawtable(fn))

    local material_info = {}

	for k, v in pairs(material) do
		local loader = loaders[k]
        if loader then
            local t = type(v)
			if t == "string" then
				-- read file under .material file folder, if not found try from assets path
				local function filter_path(parentpath, p)					
					local subres_path = parentpath / p
					if not fs.exists(subres_path) then
						return p
					end
						
					return subres_path
				end
				local subres_path = filter_path(fn:parent_path(), fs.path(v))
                material_info[k] = assetmgr.load(subres_path)
			elseif t == "table" then
				material_info[k] = loader(v)
            end
        else
            material_info[k] = v
		end
	end
	
	-- surface_type
	local surface = material_info.surface_type
	
	local def_surface = ru.default_surface_type()
	if surface == nil then
		material_info.surface_type = def_surface
	else
		for k, v in pairs(def_surface) do
			if surface[k] == nil then
				surface[k] = v
			end
		end
	end

    return material_info
end