package.path = table.concat(
    {
        "tools/import_model/?.lua",
        "engine/?.lua",
        "packages/?.lua",
        "packages/glTF/?.lua",
        "packages/serialize/?.lua",
        "packages/utility/?.lua",
        "packages/compile_resource/?.lua",
    }, ";"
)

local packages = {
    ["ant.glTF"] = {
        util = require "glTF.util",
        glb = require "glTF.glb",
    },
    ["ant.render"] = {
        declmgr = require "render.vertexdecl_mgr",
    },
    ["ant.utility"] = {
        fs_local = require "utility.fs_local",
    }
}

function import_package(pkgname)
    local pkg = packages[pkgname]
    if pkg == nil then
        error(("invalid package name:%s"):format(pkgname))
    end

    return pkg
end

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
local fs_local = require "utility.fs_local"

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
arguments.visualpath = fs.path(arguments.visualpath)

if fs.exists(arguments.config) then
    arguments.config = fs_local.datalist(arguments.config)
else
    error(("config file not found:%s"):format(arguments.config:string()))
end

arguments.outfolder = arguments.outfolder / arguments.input:stem()
arguments.visualpath = arguments.visualpath / arguments.input:stem()

function arguments:to_visualpath(localpath)
    return fs.path(localpath:string():gsub(self.outfolder:string(), self.visualpath:string()))
end

function arguments:to_localpath(visualpath)
    return fs.path(visualpath:string():gsub(self.visualpath:string(), self.outfolder:string()))
end

local extname = arguments.input:extension():string():upper()
local outfile = arguments.outfolder / "meshes" / arguments.input:filename()
if extname == ".FBX" then
    local fbx2gltf = require "fbx2gltf"
    fs.create_directories(outfile:parent_path())
    outfile:replace_extension ".glb"
    local results = fbx2gltf { {arguments.input, outfile}}
    if not next(results) then
        print("failed to convert file:", arguments.input:string(), "from fbx to gltf file")
    end

    if not fs.exists(outfile) then
        error(string.format("glb file is not exist, but fbx2gltf progrom return true:%s", arguments.input:string()))
    end
elseif extname == ".GLB" then
    fs.copy_file(arguments.input, outfile)
end

arguments.input = outfile

local importgltf = require "import_gltf"
importgltf(arguments)
