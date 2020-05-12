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
            -i, --input: for input file
            -o, --outfolder: for file to output
            -v, --visualpath: outfolder's visual path
            --disable: specify which type resource not output, can be: animation/mesh/pbrm
            --config: config file, a datalist file
        examples:
            cd to [antfolder], and run:
            {luafolder}/lua.exe tools/import_model/import.lua --input "d:/abc/female.fbx" --outfolder "d:/Work/ant/packages/resources/test" \
            --visualpath "/pkg/ant.resources/test" --config "d:/abc/config.txt" --disable "animation"
    ]]
end

local fs = require "filesystem.local"
package.loaded["filesystem"] = fs
local fs_local = require "utility.fs_local"

local function refine_path(p)
    local pp = p:match "(.+)[/\\]$"
    return fs.path(pp or p)
end

local function print_help(idx)
    print(help_info())
    return idx
end

local function throw_error(fmt, ...)
    print(fmt:format(...))
    error(print_help())
end

local function read_arguments()
    local arguments = {}
    local function read_input(idx)
        local na = arg[idx+1]
        if na == nil then
            throw_error("need argument for input:%d", idx+1)
        end

        local inputfile = fs.path(na)
        if not fs.is_regular_file(inputfile) then
            throw_error("input argument must be a file:%d %s", idx+1, inputfile:string())
        end

        local ext = inputfile:extension():string():upper()
        if ext ~= ".FBX" and ext ~= ".GLB" then
            throw_error("input file only support FBX or GLB file:%d %s", idx+1, inputfile:string())
        end

        arguments.input = inputfile
        return idx+1
    end

    local function read_outfolder(idx)
        local na = arg[idx+1]
        if na == nil then
            throw_error("need argument for outfolder:%d", idx+1)
        end
        local outfolder = fs.path(na)
        if fs.is_regular_file(outfolder) then
            throw_error("outfolder argument must be a directory:%d, %s", idx+1, outfolder:string())
        end
        arguments.outfolder = refine_path(outfolder:string())
        return idx+1
    end

    local function read_config(idx)
        local na = arg[idx+1]
        if na == nil then
            throw_error("need argument for config:%d", idx+1)
        end

        local cfgfile = fs.path(na)
        if not fs.is_regular_file(cfgfile) then
            throw_error("config file must be a file:%d %s", idx+1, arguments.config:string())
        end

        arguments.config = fs_local.datalist(cfgfile)
        return idx+1
    end

    local function read_visualpath(idx)
        local na = arg[idx+1]
        if na == nil then
            throw_error("need argument for visualpath:%d", idx+1)
        end

        arguments.visualpath = refine_path(na)
        return idx+1
    end

    local function read_disable_output(idx)
        local na = arg[idx+1]
        if na == nil then
            throw_error("need argument for visualpath:%d", idx+1)
        end

        local valid_features = {
            mesh = true,
            pbrm = true,
            animation = true,
        }

        local disables = {}
        for m in na:gmatch "[^|]+" do
            if valid_features[m] then
                disables[m] = true
            else
                throw_error("unknow feature:%d %s %s", idx+1, m, na)
            end
        end

        arguments.disable_output = disables
        return idx+1
    end

    local commands = {
        ["--input"]     = read_input,
        ["-i"]          = read_input,
        ["--outfolder"] = read_outfolder,
        ["-o"]          = read_outfolder,
        ["--config"]    = read_config,
        ["--visualpath"]= read_visualpath,
        ["-v"]          = read_visualpath,
        ["--disable"]   = read_disable_output,
        ["--help"]      = print_help,
        ["-h"]          = print_help,
    }

    local idx = 1
    while idx < #arg do
        local a = arg[idx]
        if a:match "-" or a:match "--" then
            local cmd = commands[a]
            if cmd == nil then
                throw_error(("not support command:%s"):format(a))
            end

            idx = cmd(idx)
        end

        idx = idx + 1
    end
    return arguments
end

local arguments = read_arguments()

if not (arguments and arguments.input and arguments.outfolder and arguments.config) then
    print(help_info())
    return
end

function arguments:to_visualpath(localpath)
    return fs.path(localpath:string():gsub(self.outfolder:string(), self.visualpath:string()))
end

function arguments:to_localpath(visualpath)
    return fs.path(visualpath:string():gsub(self.visualpath:string(), self.outfolder:string()))
end

local extname = arguments.input:extension():string():upper()
local meshfolder = arguments.outfolder / "meshes"
fs.create_directories(meshfolder)

local outfile = meshfolder / arguments.input:filename()
if extname == ".FBX" then
    local fbx2gltf = require "fbx2gltf"
    outfile:replace_extension ".glb"
    local results = fbx2gltf { {arguments.input, outfile}}
    if not next(results) then
        print("failed to convert file:", arguments.input:string(), "from fbx to gltf file")
    end

    if not fs.exists(outfile) then
        error(string.format("glb file is not exist, but fbx2gltf progrom return true:%s", arguments.input:string()))
    end
elseif extname == ".GLB" then
    fs.copy_file(arguments.input, outfile, true)
end

arguments.input = outfile

local importgltf = require "import_gltf"
importgltf(arguments)
