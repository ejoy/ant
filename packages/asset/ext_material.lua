local assetutil = require "util"
local assetmgr = require "asset"
local fs = require "filesystem"
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
				local subrespath = fs.path(v)
				if not subrespath:is_absolute() then
					local dir = filename:parent_path()
					local fullpath = dir / subrespath
					if not fs.exists(fullpath) then
						fullpath = assetmgr.get_depiction_path(fullpath)
						if fullpath == nil or not fs.exists(fullpath) then
							fullpath = fs.path("/pkg") / filename:package_name() / subrespath
						end
					end
					subrespath = fullpath
				end

				material_info[k] = assetmgr.load(subrespath)

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