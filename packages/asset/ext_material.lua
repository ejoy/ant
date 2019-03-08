local assetutil = require "util"
local assetmgr = require "asset"
local pfs = require "filesystem.pkg"
local ru = import_package "ant.render".util

local loaders = {
	state = function (t) return t end, 
	shader = function (t)
		return assetutil.shader_loader(t)
	end
}

return function(filename)
	local material = assetmgr.get_depiction(filename)

    local material_info = {}

	for k, v in pairs(material) do
		local loader = loaders[k]
        if loader then
			if type(v) == "string" then
				-- read file under .material file folder, if not found try from assets path
				local pkgname = filename:root_name()
				local dir = filename:parent_path()
				local fullpath = dir / v
				if not pfs.exists(fullpath) then
					fullpath = pkgname /v
				end
                material_info[k] = assetmgr.load(fullpath)
			elseif type(v) == "table" then
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