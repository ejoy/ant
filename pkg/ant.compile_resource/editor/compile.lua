local lfs     = require "filesystem.local"
local sha1    = require "editor.hash".sha1
local config  = require "editor.config"
local depends = require "editor.depends"
local vfs     = require "vfs"
local ltask   = require "ltask"

local function get_filename(pathname)
    pathname = pathname:lower()
    local filename = pathname:match "[/]?([^/]*)$"
    return filename.."_"..sha1(pathname)
end

local compile_file

local function compile(pathstring)
    local pos = pathstring:find("|", 1, true)
    if pos then
        local resource = vfs.realpath(pathstring:sub(1,pos-1))
        return compile_file(lfs.path(resource)) / pathstring:sub(pos+1):gsub("|", "/")
    else
        return lfs.path(vfs.realpath(pathstring))
    end
end

local function absolute_path(base, path)
	if path:sub(1,1) == "/" then
		return compile(path)
	end
	return lfs.absolute(base:parent_path() / (path:match "^%./(.+)$" or path))
end

local compiled = {}
local compiling = {}

function compile_file(input)
    local inputstr = input:string()
    if compiled[inputstr] then
        return compiled[inputstr]
    end
    if compiling[inputstr] then
        ltask.multi_wait(compiling[inputstr])
        return compiled[inputstr]
    end
    compiling[inputstr] = {}
    local ext = inputstr:match "[^/]%.([%w*?_%-]*)$"
    local cfg = config.get(ext)
    local output = cfg.binpath / get_filename(inputstr)
    local changed = depends.dirty(output / ".dep")
    if changed then
        local ok, deps = cfg.compiler(input, output, function (path)
            return absolute_path(input, path)
        end, changed)
        if not ok then
            local err = deps
            error("compile failed: " .. input:string() .. "\n" .. err)
        end
        depends.insert_front(deps, input)
        depends.writefile(output / ".dep", deps)
    end
    compiled[inputstr] = output
    compiling[inputstr] = nil
    ltask.multi_wakeup(compiling[inputstr])
    return output
end

return {
    init_setting = config.init,
    set_setting  = config.set,
    compile_file = compile_file,
}
