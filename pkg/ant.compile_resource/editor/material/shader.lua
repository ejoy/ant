local SHADERC    = import_package "ant.subprocess".tool_exe_path "shaderc"
local subprocess = require "editor.subprocess"
local sha1       = require "editor.hash".sha1
local lfs        = require "filesystem.local"
local vfs        = require "vfs"
local depends    = require "editor.depends"

local ROOT

local function init()
    ROOT = lfs.path(vfs.repopath()) / ".build" / "shader"
end

local function cmdtostr(commands)
    return table.concat(commands, " ")
end

local function get_filename(cmdstring, input)
    local filename = input:string():lower():match "[/]?([^/]*)$"
    return filename .. "_" .. sha1(cmdstring)
end

local function writefile(filename, data)
    local f <close> = assert(lfs.open(filename, "wb"))
    f:write(data)
end

local function run(commands, input, output)
    table.insert(commands, 1, SHADERC:string())
    local cmdstring = cmdtostr(commands)
    local path = ROOT / get_filename(cmdstring, input)
    if lfs.exists(path / "bin") then
        local deps = depends.read_if_not_dirty(path / ".dep")
        if deps then
            lfs.copy_file(path / "bin", output, lfs.copy_options.overwrite_existing)
            return true, deps
        end
    end
    lfs.remove_all(path)
    lfs.create_directories(path)
	print("shader compile:")
    print(cmdstring)
    local ok, msg = subprocess.spawn_process {
        commands,
        "-o", path / "bin",
        "--depends",
    }
    if ok then
        local INFO = msg:upper()
        for _, term in ipairs {
            "ERROR",
            "FAILED TO BUILD SHADER"
        } do
            local VARYING_ERROR<const> = ("Failed to parse varying def file"):upper()
            if INFO:find(term, 1, true) and not INFO:find(VARYING_ERROR, 1, true) then
                ok = false
                break
            end
        end
    end
    if not ok then
        return false, msg
    end
    local deps = {}
    depends.add(deps, input:string())
    local f = lfs.open(path / "bin.d")
    if f then
        f:read "l"
        for line in f:lines() do
            local path = line:match "^%s*(.-)%s*\\?$"
            if path then
                depends.add(deps, path)
            end
        end
        f:close()
    end
    depends.writefile(path / ".dep", deps)
    writefile(path / ".arguments", cmdstring)
    lfs.copy_file(path / "bin", output, lfs.copy_options.overwrite_existing)
    return true, deps
end

return {
    init = init,
    run = run,
}
