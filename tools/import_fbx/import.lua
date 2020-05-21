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
only support fbx to glb file
examples:
    cd to [antfolder], and run:
    {luafolder}/lua.exe tools/import_model/import.lua --input "d:/abc/female.fbx" --outfolder "d:/Work/ant/packages/resources/test"
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
        if ext ~= ".FBX" then
            throw_error("input file only support FBX file:%d %s", idx+1, inputfile:string())
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

    local commands = {
        ["--input"]     = read_input,
        ["-i"]          = read_input,
        ["--outfolder"] = read_outfolder,
        ["-o"]          = read_outfolder,
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

if not (arguments and arguments.input and arguments.outfolder) then
    print(help_info())
    return
end

local extname = arguments.input:extension():string():upper()
local outfile = arguments.outfolder / arguments.input:filename()
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
end