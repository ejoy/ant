local fs    = require "filesystem"
local lfs   = require "filesystem.local"
local sha1  = require "editor.hash".sha1
local datalist = require "datalist"
local config    = require "editor.config"
local vfs = require "vfs"
local compile = require "compile".compile

local function writefile(filename, data)
	local f = assert(lfs.open(filename, "wb"))
	f:write(data)
	f:close()
end

local function readfile(filename)
	local f = assert(lfs.open(filename))
	local data = f:read "a"
	f:close()
	return data
end

local function get_filename(pathname)
    pathname = pathname:lower()
    local filename = pathname:match "[/]?([^/]*)$"
    return filename.."_"..sha1(pathname)
end

local function readconfig(filename)
    return datalist.parse(readfile(filename))
end

local function do_build(output)
    local depfile = output / ".dep"
    if not lfs.exists(depfile) then
        return
    end
	for _, dep in ipairs(readconfig(depfile)) do
        local timestamp, filename = dep[1], lfs.path(dep[2])
        if timestamp == 0 then
            if lfs.exists(filename) then
                return
            end
        else
            if not lfs.exists(filename) or timestamp ~= lfs.last_write_time(filename) then
                return
            end
        end
	end
	return true
end

local function create_depfile(filename, deps)
    local w = {}
    for _, file in ipairs(deps) do
        local path = lfs.path(file)
        if lfs.exists(path) then
            w[#w+1] = ("{%d, %q}"):format(lfs.last_write_time(path), lfs.absolute(path):string())
        else
            w[#w+1] = ("{0, %q}"):format(lfs.absolute(path):string())
        end
    end
    writefile(filename, table.concat(w, "\n"))
end

local function absolute_path(base, path)
	if path:sub(1,1) == "/" then
        if path:find("|", 1, true) then
            return compile(path)
        end
		return fs.path(path):localpath()
	end
	return lfs.absolute(base:parent_path() / (path:match "^%./(.+)$" or path))
end

local function do_compile(cfg, input, output)
    lfs.create_directory(output)
    local ok, deps = cfg.compiler(input, output, cfg.setting, function (path)
        return absolute_path(input, path)
    end)
    if not ok then
        local err = deps
        error("compile failed: " .. input:string() .. "\n" .. err)
    end
    create_depfile(output / ".dep", deps or {})
end

local function compile_file(input)
    local inputstr = input:string()
    local ext = inputstr:match "[^/]%.([%w*?_%-]*)$"
    local cfg = config.get(ext)
    local output = cfg.binpath / get_filename(inputstr:lower())
    if not do_build(output) then
        do_compile(cfg, input, output)
    end
    return output
end

function vfs.resource(urllst)
    assert(#urllst >= 2)
    local folder = compile_file(fs.path(urllst[1]):localpath())
    for i = 2, #urllst - 1 do
        folder = compile_file(folder / urllst[i])
    end
    return folder / urllst[#urllst]
end

function vfs.resource_setting(ext, setting)
    config.set(ext, setting)
end

if vfs.sync then
    vfs.sync.resource = vfs.resource
    vfs.sync.resource_setting = vfs.resource_setting
end

if vfs.async then
    vfs.async.resource = vfs.resource
    vfs.async.resource_setting = vfs.resource_setting
end
