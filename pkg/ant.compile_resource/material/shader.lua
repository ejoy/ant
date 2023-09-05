local SHADERC    = require "tool_exe_path"("shaderc")
local subprocess = require "subprocess"
local sha1       = require "sha1"
local lfs        = require "bee.filesystem"
local vfs        = require "vfs"
local ltask      = require "ltask"
local depends    = require "depends"

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
    local f <close> = assert(io.open(filename:string(), "wb"))
    f:write(data)
end

local waiting = {}
local function wait_close(t)
    waiting[t._] = nil
    ltask.multi_wakeup(t._)
end
local wait_closeable = {__close=wait_close}
local function wait_start(pathkey)
    if waiting[pathkey] then
        ltask.multi_wait(pathkey)
    end
    waiting[pathkey] = true
    return setmetatable({_=pathkey}, wait_closeable)
end

local function run(commands, input, output)
    table.insert(commands, 1, SHADERC:string())
    local cmdstring = cmdtostr(commands)
    local path = ROOT / get_filename(cmdstring, input)
    local pathkey = path:string()
    local _ <close> = wait_start(pathkey)
    if lfs.exists(path / "bin") then
        local deps = depends.read_if_not_dirty(path / ".dep")
        if deps then
            lfs.copy_file(path / "bin", output, lfs.copy_options.overwrite_existing)
            return true, deps
        end
    end
    lfs.remove_all(path)
    lfs.create_directories(path)
    local C = {
        commands,
        "-o", (path / "bin"):string(),
        "--depends",
    }
    print "shader compile:"
    local ok, msg = subprocess.spawn_process(C)
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
    local f = io.open((path / "bin.d"):string())
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
