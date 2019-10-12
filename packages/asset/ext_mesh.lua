local assetutil	= require "util"
local bgfx 		= require "bgfx"

local mesh_loader 	= import_package "ant.modelloader".loader

return { 
	loader = function (filename)
		local meshcontent, binary = assetutil.parse_embed_file(filename)
		return mesh_loader.load(binary)
	end,
	unloader = function(res)
		local meshscene = res
		local handles = {}
		for _, scene in ipairs(meshscene.scenes) do
			for _, node in ipairs(scene) do
				for _, prim in ipairs(node) do
					for _, h in ipairs(assert(prim.vb.handles)) do
						handles[h] = true
					end

					if prim.ib then
						handles[prim.ib.handle] = true
					end
				end
			end
		end

		for h in pairs(handles) do
			bgfx.destroy(h)
		end
	end,
}

