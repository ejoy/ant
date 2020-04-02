local assetutil = import_package "ant.fileconvert".util
local mesh_loader 	= import_package "ant.modelloader".loader

return { 
	loader = function (filename)
		local meshcontent, binary = assetutil.parse_embed_file(filename)
		return mesh_loader.load(assert(binary), meshcontent)
	end,
	unloader = function(res)
	end,
}
