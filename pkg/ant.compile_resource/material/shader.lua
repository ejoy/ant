local SHADERC    = require "tool_exe_path"("shaderc")
local subprocess = require "subprocess"
local sha1       = require "sha1"
local lfs        = require "bee.filesystem"
local ltask      = require "ltask"
local depends    = require "depends"
local clonefile  = require "clonefile"

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

local compiling = {}

local function compile_finish(key, ...)
    ltask.multi_wakeup(compiling[key], ...)
    compiling[key] = nil
    return ...
end

local function run(setting, commands, input, output)
    local cmdstring = cmdtostr(commands)
    local path = setting.shaderpath / get_filename(cmdstring, input)
    local pathkey = path:string()

    if compiling[pathkey] then
        local ok, res = ltask.multi_wait(compiling[pathkey])
        if ok then
            clonefile(path / "bin", output)
        end
        return ok, res
    end
    compiling[pathkey] = {}

    if lfs.exists(path) then
        if lfs.exists(path / "bin") and lfs.exists(path / ".dep")  then
            local deps, dirty_path = depends.read_if_not_dirty(setting.vfs, path / ".dep")
            if deps then
                clonefile(path / "bin", output)
                return compile_finish(pathkey, true, deps)
            elseif dirty_path then
                log.warn(("`%s` is dirty. reason: `%s`"):format(path, dirty_path))
            else
                log.error(("`%s/.dep` does not exist."):format(path))
            end
        end
        lfs.remove_all(path)
    end
    lfs.create_directories(path)
    local C = {
        SHADERC:string(),
        commands,
        "-o", (path / "bin"):string(),
        "--depends",
    }
    print "shader compile:"
    local success, errmsg, outmsg = subprocess.spawn(C)
    if success then
        local INFO = outmsg:upper()
        for _, term in ipairs {
            "ERROR",
            "FAILED TO BUILD SHADER"
        } do
            local VARYING_ERROR<const> = ("Failed to parse varying def file"):upper()
            if INFO:find(term, 1, true) and not INFO:find(VARYING_ERROR, 1, true) then
                success = false
                break
            end
        end
    end
    if not success then
        return compile_finish(pathkey, false, errmsg)
    end
    local deps = depends.new()
    depends.add_lpath(deps, input:string())
    local f = io.open((path / "bin.d"):string())
    if f then
        f:read "l"
        for line in f:lines() do
            local path = line:match "^%s*(.-)%s*\\?$"
            if path then
                depends.add_lpath(deps, path)
            end
        end
        f:close()
    end
    depends.writefile(path / ".dep", deps)
    writefile(path / ".arguments", cmdstring)
    clonefile(path / "bin", output)
    return compile_finish(pathkey, true, deps)
end

return {
    run = run,
}
