local export_prefab     = require "editor.model.export_prefab"
local export_meshbin    = require "editor.model.export_meshbin"
local export_animation  = require "editor.model.export_animation"
local export_material   = require "editor.model.export_material"
local glbloader         = require "editor.model.glTF.glb"
local utility           = require "editor.model.utility"
local depends           = require "editor.depends"
local parallel_task     = require "editor.parallel_task"
local lfs               = require "filesystem.local"

local function build_scene_tree(gltfscene)
    local scenetree = {}
	for nidx, node in ipairs(gltfscene.nodes) do
		if node.children then
			for _, cnidx in ipairs(node.children) do
				scenetree[cnidx] = nidx-1
			end
		end
	end
    return scenetree
end

return function (input, output, tolocalpath)
    lfs.remove_all(output)
    lfs.create_directories(output)
    local depfiles = {}
    depends.add(depfiles, input .. ".patch")
    utility.init(input, output)
    local glbdata = glbloader.decode(input)
    local exports = {}
    assert(glbdata.version == 2)
    exports.scenetree = build_scene_tree(glbdata.info)
    exports.depfiles = depfiles
    local tasks = parallel_task.new()
    exports.tasks = tasks
    export_meshbin(output, glbdata, exports)
    export_material(output, glbdata, exports, tolocalpath)
    export_animation(input, output, exports)
    export_prefab(output, glbdata, exports, tolocalpath)
    parallel_task.wait(tasks)
    return true, depfiles
end
