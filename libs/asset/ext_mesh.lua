-- luacheck: globals import
-- luacheck: globals log
local require = import and import(...) or require
local log = log and log(...) or print

local rawtable = require "common.rawtable"
local path = require "filesystem.path"
local mesh_loader = require "modelloader"
local assetmgr = require "asset"

local function gen_antmesh_filepath(filename)
	if path.ext(filename) then
		return path.replace_ext(filename, "antmesh")
	end
	return filename .. ".antmesh"
end	

return function (filename)
	local fn = assetmgr.find_depiction_path(filename)	
	local mesh = rawtable(fn)
    
    local mesh_path = mesh.mesh_path
    assert(mesh_path ~= nil)
    if #mesh_path ~= 0 then
		mesh_path = gen_antmesh_filepath(mesh_path)	

		mesh_path = assetmgr.find_valid_asset_path(mesh_path)
		if mesh_path then
			mesh.handle = mesh_loader.load(mesh_path)
        else
            log(string.format("load mesh path failed, %s, .mesh file:%s", mesh.mesh_path, filename))
        end 
    end
	
    return mesh
end
