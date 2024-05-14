local export_prefab     = require "model.export_prefab"
local export_meshbin    = require "model.export_meshbin"
local export_skinbin    = require "model.export_skinbin"
local export_animation  = require "model.export_animation"
local export_material   = require "model.export_material"
local export_only_ani   = require "model.export_only_ani"
local math3d_pool       = require "model.math3d_pool"
local gltf              = require "model.glTF.main"
local patch             = require "model.patch"
local depends           = require "depends"
local parallel_task     = require "parallel_task"
local lfs               = require "bee.filesystem"
local base64            = require "model.glTF.base64"
local build_animation   = require "model.build_animation"

local function readall(filename)
    local f <close> = assert(io.open(filename, "rb"))
    return f:read "a"
end

return function (lpath, vpath, output, setting, changed)
    lfs.remove_all(output)
    lfs.create_directories(output)
    local status = {
        input = lpath,
        output = output,
        setting = setting,
        tasks = parallel_task.new(),
        depfiles = depends.new(),
    }
    depends.add_lpath(status.depfiles, lpath)
    depends.add_vpath(status.depfiles, setting, "/pkg/ant.compile_resource/model/version.lua")
    status.math3d = math3d_pool.alloc(status.setting)
    status.patch = patch.init(lpath, vpath, status.depfiles)

    local gltf_cwd = lfs.path(lpath):remove_filename():string()
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
    status.gltfscene = gltf.decode(lpath, status.gltf_fetch)

    local gltfscene = status.gltfscene
    if gltfscene.animations then
        status.animation = {}
        export_animation(status)
        if gltfscene.skins then
            export_skinbin(status)
        end
    end

	if lfs.path(lpath):stem():extension() == ".ani" then
		assert (status.animation, "No animation in .ani file")
        build_animation(status)
		export_only_ani(status)
	else
		export_meshbin(status)
		export_material(status)
		export_prefab(status)
		parallel_task.wait(status.tasks)
	end
    math3d_pool.free(status.math3d)
    return true, status.depfiles
end
