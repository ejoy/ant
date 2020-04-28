local fs        = require "filesystem"
local cr        = import_package "ant.compile_resource"
local assetutil = cr.util
local math3d = require "math3d"

local function create_bounding(bounding)
	if bounding then
		bounding.aabb = math3d.ref(math3d.aabb(bounding.aabb[1], bounding.aabb[2]))
	end
end

return {
	loader = function (filename)
        local outpath = cr.compile(fs.path(filename):localpath())
		local meshscene = assetutil.read_embed_file(outpath / "main.index")
		for _, scene in pairs(meshscene.scenes) do
			for _, meshnode in pairs(scene) do
				create_bounding(meshnode.bounding)
				for _, prim in ipairs(meshnode) do
					create_bounding(prim.bounding)
				end
			end
		end
		return meshscene
	end,
	unloader = function(res)
	end,
}
