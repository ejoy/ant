local export_prefab     = require "model.export_prefab"
local export_meshbin    = require "model.export_meshbin"
local export_animation  = require "model.export_animation"
local export_material   = require "model.export_material"
local math3d_pool       = require "model.math3d_pool"
local glbloader         = require "model.glTF.glb"
local patch             = require "model.patch"
local depends           = require "depends"
local parallel_task     = require "parallel_task"
local lfs               = require "bee.filesystem"

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

return function (input, output, setting, changed)
    lfs.remove_all(output)
    lfs.create_directories(output)
    local status = {
        input = input,
        output = output,
        setting = setting,
        tasks = parallel_task.new(),
        depfiles = depends.new(),
        post_tasks = parallel_task.new(),
    }
    depends.add_lpath(status.depfiles, input)
    depends.add_vpath(status.depfiles, setting, "/pkg/ant.compile_resource/model/version.lua")
    status.math3d = math3d_pool.alloc(status.setting)
    status.patch = patch.init(input, status.depfiles)
    status.glbdata = glbloader.decode(input)
    assert(status.glbdata.version == 2)
    status.scenetree = build_scene_tree(status.glbdata.info)
    export_meshbin(status)
    export_material(status)
    export_animation(status)
    export_prefab(status)
    parallel_task.wait(status.tasks)
    parallel_task.wait(status.post_tasks)
    math3d_pool.free(status.math3d)
    return true, status.depfiles
end
