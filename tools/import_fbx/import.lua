package.path = table.concat(
    {
        "tools/import_fbx/?.lua",
        "engine/?.lua",
        "packages/?.lua",
        "packages/utility/?.lua",
    }, ";"
)

local function help_info()
    return [[
only support fbx to glb file
examples:
    cd to [antfolder], and run:
    {luafolder}/lua.exe tools/import_fbx/import.lua --input "d:/abc/female.fbx" --output "d:/Work/ant/packages/resources/test/female.glb"
    ]]
end

local fs = require "filesystem.local"
package.loaded["filesystem"] = fs

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
        if fs.is_regular_file(inputfile) then
            local ext = inputfile:extension():string():upper()
            if ext ~= ".FBX" then
                throw_error("input file only support FBX file:%d %s", idx+1, inputfile:string())
            end
        end

        if not fs.is_directory(inputfile) then
            throw_error("'input' must be file or directory", idx, inputfile)
        end
        arguments.input = inputfile
        return idx+1
    end

    local function read_output(idx)
        local na = arg[idx+1]
        if na == nil then
            throw_error("need argument for outfolder:%d", idx+1)
        end
        local output = fs.path(na)
        arguments.output = refine_path(output:string())
        return idx+1
    end

    local function read_cache(idx)
        local na = arg[idx+1]
        if na == nil then
            throw_error("need argument for cache folder:%d", idx+1)
        end

        local cache = fs.path(na)
        arguments.cache_folder = refine_path(cache:string())
        return idx+1
    end

    local commands = {
        ["--input"]  = read_input,
        ["-i"]       = read_input,
        ["--output"] = read_output,
        ["-o"]       = read_output,
        ["--cache"]  = read_cache,
        ["--help"]   = print_help,
        ["-h"]       = print_help,
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

if not (arguments and arguments.input and arguments.output) then
    print(help_info())
    return
end

fs.create_directories(fs.path(arguments.output):parent_path())

local function cvt_fbx(fbxfile, outfile)
    local fbx2gltf = require "fbx2gltf"

    if not fs.is_directory(arguments.cache_folder) then
        fs.create_directories(arguments.cache_folder)
    end

    local tmpfile = arguments.cache_folder / "tmp.fbx"
    fs.copy_file(fbxfile, tmpfile, true)

    local out_tmpfile = fs.path(tmpfile):replace_extension ".glb"
    local ok = fbx2gltf(tmpfile, out_tmpfile)

    if not ok then
        print("failed to convert file:", fbxfile, "from fbx to gltf file")
        return
    end

    if not fs.exists(fs.path(out_tmpfile)) then
        error(string.format("glb file is not exist, but fbx2gltf progrom return true:%s", out_tmpfile))
    end

    local parentpath = outfile:parent_path()
    if not fs.is_directory(parentpath) then
        fs.create_directories(parentpath)
    end

    fs.copy_file(out_tmpfile, outfile, true)
end

if fs.is_regular_file(arguments.input) then
    cvt_fbx(arguments.input, arguments.output)
elseif fs.is_directory(arguments.input) then
    if fs.is_regular_file(arguments.output) then
        error(("invalid 'output' as file, should be folder:%s"):format(arguments.output))
    end
    if not fs.is_directory(arguments.output) then
        fs.create_directories(arguments.output)
    end

    local function list_all_files(path)
        local files = {}
        local function l(path)
            for p in path:list_directory() do
                if fs.is_directory(p) then
                    l(p)
                elseif fs.is_regular_file(p) then
                    if p:extension():string():upper() == ".FBX" then
                        files[#files+1] = p
                    end
                end
            end
        end

        l(path)
        return files
    end

    for _, f in ipairs(list_all_files(arguments.input)) do
        local subname = f:string():gsub(arguments.input:string() .. "[/\\]?", "")
        local output = arguments.output / fs.path(subname):replace_extension ".glb"
        cvt_fbx(f, output)
    end
end

-- _G.import_package = function (pkgname)
--     if pkgname == "ant.json" then
--         return require "json.json"
--     end
-- end

-- local glbloader = require "compile_resource.model.glTF.glb"
-- local info = glbloader.decode(arguments.output)
-- print(info.info)