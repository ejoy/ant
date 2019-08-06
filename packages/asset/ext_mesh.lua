local assetmgr 		= require "asset"
local fs 			= require "filesystem"
local bgfx 			= require "bgfx"

local mesh_loader 	= import_package "ant.modelloader".loader

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
		local reshandle = res.handle
		local meshscene = reshandle.handle
		for _, scene in ipairs(meshscene.scenes) do
			for _, node in ipairs(scene) do
				for _, prim in ipairs(node) do
					for _, h in ipairs(assert(prim.vb.handles)) do
						bgfx.destroy(h)
					end

					if prim.ib then
						bgfx.destroy(assert(prim.ib.handle))
					end
				end
			end
		end

		res.handle = nil
	end,
}

