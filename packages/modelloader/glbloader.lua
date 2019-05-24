local util = require "util"
local glbloader = import_package "ant.glTF".glb
return function (meshfile)
	local glbdata = glbloader.decode_from_filehandle(meshfile)
	local scene = util.init_scene(glbdata.info, glbdata.bin)

	local sceneidx = scene.scene
	local scenenodes = scene.scenes[sceneidx+1]

	local newscene = {
		nodes = {},
		meshes = {},
		accessors = {},
		bufferViews = {},
	}

	local function mark_accessor(accidx)
		newscene.accessors[accidx+1] = true
		local accessor = scene.accessors[accidx+1]
		newscene.bufferViews[accessor.bufferView+1] = true
	end

	local function mark_valid_fileds(scenenodes)
		for _, nodeidx in ipairs(scenenodes) do
			local node = scene.nodes[nodeidx+1]
			newscene.nodes[nodeidx+1] = true

			if node.children then
				mark_valid_fileds(node.children)
			end
			local meshidx = node.mesh
			if meshidx then
				newscene.meshes[meshidx+1] = true
				local mesh = scene.meshes[meshidx+1]
				for _, prim in ipairs(mesh.primitives) do
					for _, accidx in pairs(prim.attributes)do
						mark_accessor(accidx)
					end
					
					mark_accessor(prim.indices)
				end
			end
		end
	end

	mark_valid_fileds(scene.scenes[scene.scene+1].nodes)

	for k, field in pairs(scene) do
		local newfield = newscene[k]
		if newfield then
			for idx in ipairs(field) do
				if not newfield[idx] then
					field[idx] = false
				end
			end
		else
			scene[k] = nil
		end
	end

	scene.scene = sceneidx
	scene.scenes = {scenenodes}
	return scene
end