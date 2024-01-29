local export_prefab     = require "model.export_prefab"
local export_meshbin    = require "model.export_meshbin"
local export_animation  = require "model.export_animation"
local export_material   = require "model.export_material"
local math3d_pool       = require "model.math3d_pool"
local gltf              = require "model.glTF.main"
local patch             = require "model.patch"
local depends           = require "depends"
local parallel_task     = require "parallel_task"
local lfs               = require "bee.filesystem"
local base64            = require "model.glTF.base64"

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

local function readall(filename)
    local f <close> = assert(io.open(filename, "rb"))
    return f:read "a"
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

    local gltf_cwd = lfs.path(input):remove_filename():string()
    function status.gltf_fetch(uri)
        if uri:sub(1, 5) == "data:" then
            local match = uri:match "^data:[a-z-]+/[a-z-]+;base64,"
            assert(match)
            return base64.decode(uri:sub(#match + 1))
        end
        local fullpath = gltf_cwd .. uri
        depends.add_lpath(status.depfiles, fullpath)
        return readall(fullpath)
    end
    status.gltfscene = gltf.decode(input, status.gltf_fetch)
    status.scenetree = build_scene_tree(status.gltfscene)

    export_meshbin(status)
    export_material(status)
    export_animation(status)
    export_prefab(status)
    parallel_task.wait(status.tasks)
    parallel_task.wait(status.post_tasks)
    math3d_pool.free(status.math3d)
    return true, status.depfiles
end
