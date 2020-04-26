package.path = table.concat(
    {
        "tools/import_model/?.lua",
        "engine/?.lua",
        "packages/?.lua",
        "packages/glTF/?.lua",
        "packages/serialize/?.lua",
    }, ";"
)

local function help_info()
    return [[
        we need at least to argument: input and outfolder, each for input file and output folder.
        we will output files included:
            1. ['pbrm']-pbrm files: for pbr material
            2. ['ozz']-animation relative files: included skeleton and animation file['ozz']
            3. ['meshbin']-meshbin files: mesh consist of vb and ib info
            4. ['txt']-entity files: entity for runtime, it included 'hierarchy' and 'mesh' entity
        argument:
            input: for input file
            outfolder: for file to output
            config: config file, a datalist file
        examples:
            cd to [antfolder], and run:
            {luafolder}/lua.exe tools/import_model/import.lua input=d:/abc/female.fbx outfolder=d:/abc/female \
            config=d:/abc/config.txt
    ]]
end

local fs = require "filesystem.local"
package.loaded["filesystem"] = fs
local fs_util = require "utility.fs_util"

local function read_arguments()
    local arguments = {}
    for _, a in ipairs(arg) do
        local name, value = a:match "([^=]+)%s*=([^%s]+)"
        arguments[name] = value
    end

    return arguments
end

local arguments = read_arguments()

if not (arguments and arguments.input and arguments.outfolder and arguments.config) then
    print(help_info())
    return
end

arguments.config = fs.path(arguments.config)
arguments.input = fs.path(arguments.input)
arguments.outfolder = fs.path(arguments.outfolder)

local cfg = fs.exists(arguments.config) and fs_util.datalist(arguments.config) or nil

if arguments.input:extension():string():upper() == ".FBX" then
    local fbx2gltf = require "fbx2gltf"
    local results = fbx2gltf {arguments.input}
    if not next(results) then
        print("failed to convert file:", arguments.input:string(), "from fbx to gltf file")
    end

    local glbfile = fs.path(arguments.input):replace_extension "glb"
    if not fs.exists(glbfile) then
        error(string.format("glb file is not exist, but fbx2gltf progrom return true:%s", arguments.input:string()))
    end
    arguments.input = glbfile
end


local importgltf = require "import_gltf"

importgltf(arguments.input, arguments.outfolder, cfg)
