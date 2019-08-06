local log = log or print

local mesh_loader = import_package "ant.modelloader".loader
local assetmgr = require "asset"
local fs = require "filesystem"

return { 
	loader = function (filename)
		local mesh = assetmgr.get_depiction(filename)
		local meshpath =  fs.path(mesh.mesh_path)
		if fs.exists(meshpath) then
			mesh.handle = mesh_loader.load(meshpath)
		else
			log.warn(string.format("load mesh path failed, mesh file:[%s], .mesh file:[%s],", meshpath, filename))
		end 
		return mesh
	end,
	unloader = function(res)
		local meshscene = res.handle
		for _, scene in ipairs(meshscene.scenes) do
			for _, node in ipairs(scene) do
				for _, prim in ipairs(node) do
					for _, h in ipairs(prim.vb) do
						bgfx.destroy(h)
					end

					if prim.ib then
						bgfx.destroy(prim.ib)
					end
				end
			end
		end

		res.handle = nil
	end,
}

