local util = require "util"
local glbloader = import_package "ant.glTF".glb
return function (meshfile)
	local glbdata = glbloader.decode_from_filehandle(meshfile)
	return util.init_scene(glbdata.info, glbdata.bin)
end