local def_config= require "mesh.default_cfg"
local glb_cvt= require "mesh.glb_convertor"
local utilitypkg = import_package "ant.utility"
local fs_util = utilitypkg.fs_util
local util = require "util"

return function (config, sourcefile, outpath, localpath)
	local outfile = outpath / "main.index"
	local meshcontent = fs_util.datalist(sourcefile:localpath())
	local meshpath = localpath(meshcontent.mesh_path)

	local result = glb_cvt(meshpath:string(), meshcontent.config or def_config)

	if result then
		util.write_embed_file(outfile, result)
		return true, ""
	end

	return false, "convert file failed:" .. meshpath:string()
end
