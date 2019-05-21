local gltf = import_package "ant.glTF"
local glbloader = gltf.glb

return function (meshfile)
	local glbdata = glbloader.decode_from_filehandle(meshfile)
	local scene = glbdata.info
	local bindata = glbdata.bin

	init_glb_scene(scene, bindata)
	return scene
end