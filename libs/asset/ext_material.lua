local require = import and import(...) or require

local rawtable = require "rawtable"
local assetutil = require "asset.util"
local assetmgr = require "asset"
local vfsutil = require "vfs.util"
local path = require "filesystem.path"

return function(filename)
	local fn = assetmgr.find_valid_asset_path(filename)
	if fn == nil then
		error(string.format("invalid filename in ext_material, %s", filename))
	end

    local material = assert(rawtable(fn))
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
				-- read file under .material file folder, if not found try from assets path
				local subres_path = path.join(fn, v)
				if not vfsutil.exist(subres_path) then
					subres_path = v
				end

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
	local ru = require "render.util"
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