local require = import and import(...) or require
local log = log and log(...) or print

local rawtable = require "rawtable"
local path = require "filesystem.path"


return function (filename, param)
    local mesh = rawtable(filename)
    
    local mesh_path = mesh.mesh_path
    assert(mesh_path ~= nil)
    if #mesh_path ~= 0 then
        local assetmgr = require "asset"
        local p = assetmgr.find_valid_asset_path(mesh_path)
        if p then

			--local fbx_p = string.gsub(p, ".bin", ".fbx")
			local ext = string.lower(path.ext(p))
			if ext == "fbx" then
				local fbx_mesh_loader = require "modelloader.fbxloader"
				mesh.handle = fbx_mesh_loader.load(p)
			elseif ext == "bin" then
                local mesh_loader = require "render.resources.mesh_loader"
                mesh.handle = mesh_loader.load(p)
			end

        else
            log(string.format("load mesh path %s failed", mesh_path))
        end 
    end
    
    return mesh
end
