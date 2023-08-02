local export_prefab     = require "editor.model.export_prefab"
local export_meshbin    = require "editor.model.export_meshbin"
local export_animation  = require "editor.model.export_animation"
local export_material   = require "editor.model.export_material"
local math3d_pool       = require "editor.model.math3d_pool"
local glbloader         = require "editor.model.glTF.glb"
local patch             = require "editor.model.patch"
local depends           = require "editor.depends"
local parallel_task     = require "editor.parallel_task"
local lfs               = require "filesystem.local"
local fs                = require "filesystem"
local datalist          = require "datalist"
local material_compile  = require "editor.material.compile"

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

local function readfile(filename)
	local f <close> = assert(lfs.open(filename, "r"))
	return f:read "a"
end

local function readdatalist(filepath)
	return datalist.parse(readfile(filepath), function(args)
		return args[2]
	end)
end

local function recompile_materials(input, output, setting)
    assert(lfs.exists(output))
    local depfiles = {}
    depends.add(depfiles, input .. ".patch")
    local tasks = parallel_task.new()
    for material_path in lfs.pairs(output / "materials") do
        local mat = readdatalist(material_path / "main.cfg")
        material_compile(tasks, depfiles, mat, input, material_path, setting, function (path)
            return fs.path(path):localpath()
        end)
    end
    parallel_task.wait(tasks)
    
    return true, depfiles
end

return function (input, output, setting, localpath, changed)
    if changed ~= true and changed:match "%.s[ch]$" then
        return recompile_materials(input, output, setting)
    end
    lfs.remove_all(output)
    lfs.create_directories(output)
    local status = {
        input = input,
        output = output,
        setting = setting,
        localpath = localpath,
        tasks = parallel_task.new(),
        depfiles = {},
    }
    depends.make_depend_graphic_settings(status.depfiles, tolocalpath)

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
    math3d_pool.free(status.math3d)
    return true, status.depfiles
end
