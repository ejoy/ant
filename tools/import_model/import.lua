package.cpath = "projects/msvc/vs_bin/Debug/?.dll"
package.path = table.concat(
    {
        "tools/import_model/?.lua",
        "engine/?.lua",
        "packages/?.lua",
        "packages/glTF/?.lua",
    }, ";"
)

local function help_info()
    return [[
        At least two argument, one for import file, one for export folder
    ]]
end

if #arg < 2 then
    print(help_info())
    return
end

local fs = require "filesystem.local"

local inputfile, output_folder = fs.path(arg[1]), fs.path(arg[2])

if inputfile:extension():string():upper() == ".FBX" then
    local fbx2gltf = require "fbx2gltf"
    local results = fbx2gltf {inputfile}
    if not next(results) then
        print("failed to convert file:", inputfile:string(), "from fbx to gltf file")
    end

    local glbfile = fs.path(inputfile):replace_extension "glb"
    if not fs.exists(glbfile) then
        error(string.format("glb file is not exist, but fbx2gltf progrom return true:%s", inputfile:string()))
    end
    inputfile = glbfile
end


local importgltf = require "import_gltf"

importgltf(inputfile, output_folder)
