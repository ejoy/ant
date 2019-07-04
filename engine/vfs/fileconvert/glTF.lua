local glTF_path = "vfs.fileconvert.glTF."
return {
	glb = require(glTF_path .. "glb"),
	stringify = require(glTF_path .. "stringify"),
	util = require(glTF_path .. "util"),
}