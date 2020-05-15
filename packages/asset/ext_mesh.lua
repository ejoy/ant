local cr     = import_package "ant.compile_resource"
local math3d = require "math3d"

local function create_bounding(bounding)
	if bounding then
		bounding.aabb = math3d.ref(math3d.aabb(bounding.aabb[1], bounding.aabb[2]))
	end
end

local function loader(filename)
	local outpath = cr.compile(filename)
	local meshscene = cr.util.read_embed_file(outpath / "main.index")
	for _, scene in pairs(meshscene.scenes) do
		for _, meshnode in pairs(scene) do
			local skin = meshnode.skin
			create_bounding(meshnode.bounding)
			for _, prim in ipairs(meshnode) do
				create_bounding(prim.bounding)
				prim.skin = skin
			end
		end
	end
	return meshscene
end

local function unloader()
end

return {
    loader = loader,
    unloader = unloader,
}
