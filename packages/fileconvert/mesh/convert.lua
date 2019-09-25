local lfs = require "filesystem.local"

local config = require "mesh.default_cfg"

local glb_cvt = require "mesh.glb_convertor"

return function (identity, sourcefile, param, outfile)
	assert(param.sourcetype == "glb")
	glb_cvt(sourcefile:string(), outfile:string(), param.config or config)
	return lfs.exists(outfile)
end
