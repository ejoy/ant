local lfs     = require "filesystem.local"
local sha1    = require "editor.hash".sha1
local config  = require "editor.config"
local depends = require "editor.depends"
local vfs   = require "vfs"
local ltask   = require "ltask"

local function get_filename(pathname)
    pathname = pathname:lower()
    local filename = pathname:match "[/]?([^/]*)$"
    return filename.."_"..sha1(pathname)
end

local compile_file

local function absolute_path(base, path)
    if path:sub(1,1) == "/" then
        --assert(not path:find("|", 1, true))
        --return lfs.path(vfs.realpath(path))
        local pos = path:find("|", 1, true)
        if pos then
            local resource = vfs.realpath(path:sub(1,pos-1))
            return compile_file(lfs.path(resource)) / path:sub(pos+1):gsub("|", "/")
        else
            return lfs.path(vfs.realpath(path))
        end
    end
    return lfs.absolute(base:parent_path() / (path:match "^%./(.+)$" or path))
end

local compiling = {}

function compile_file(input)
    local inputstr = input:string()
    if compiling[inputstr] then
        return lfs.path(ltask.multi_wait(compiling[inputstr]))
    end
    compiling[inputstr] = {}
    local ext = inputstr:match "[^/]%.([%w*?_%-]*)$"
    local cfg = config.get(ext)
    local output = cfg.binpath / get_filename(inputstr)
    local changed = depends.dirty(output / ".dep")
    if changed then
        local ok, deps = cfg.compiler(input, output, cfg.setting, function (path)
            return absolute_path(input, path)
        end, changed)
        if not ok then
            local err = deps
            error("compile failed: " .. input:string() .. "\n" .. err)
        end
        depends.insert_front(deps, input)
        depends.writefile(output / ".dep", deps)
    end
    ltask.multi_wakeup(compiling[inputstr], output:string())
    compiling[inputstr] = nil
    return output
end

return {
    init_setting = config.init,
    set_setting  = config.set,
    compile_file = compile_file,
}
