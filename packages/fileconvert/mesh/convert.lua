local config= require "mesh.default_cfg"
local glb_cvt= require "mesh.glb_convertor"
local util 	= require "util"

return function (identity, sourcefile, outfile, localpath)
	local meshcontent = util.datalist(sourcefile)
	local meshpath = localpath(meshcontent.mesh_path)

	local result = glb_cvt(meshpath:string(), meshcontent.config or config)

	if result then
		util.write_embed_file(outfile, result)
		return true, ""
	end

	return false, "convert file failed:" .. meshpath:string()
end
