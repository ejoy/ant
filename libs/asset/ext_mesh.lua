-- luacheck: globals import
-- luacheck: globals log
local require = import and import(...) or require
local log = log and log(...) or print

local rawtable = require "rawtable"
local path = require "filesystem.path"
local mesh_loader = require "modelloader.loader"
local assetmgr = require "asset"

return function (filename)
	local fn = assetmgr.find_depiction_path(filename)
    local mesh = rawtable(fn)
    
    local mesh_path = mesh.mesh_path
    assert(mesh_path ~= nil)
    if #mesh_path ~= 0 then		
		local function check_path(fp)
			if path.ext(fp) == nil then					
				for _, ext in ipairs {".fbx", ".bin", ".ozz"} do
					local pp = assetmgr.find_valid_asset_path(fp .. ext)
					if pp then
						return pp
					end
				end
			end

			return assetmgr.find_valid_asset_path(fp)
		end

		mesh_path = check_path(mesh_path)
		if mesh_path then
			mesh.handle = mesh_loader.load(mesh_path)
        else
            log(string.format("load mesh path failed, %s, .mesh file:%s", mesh.mesh_path, filename))
        end 
    end
    
    return mesh
end
