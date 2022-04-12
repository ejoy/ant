local fs = require "filesystem"
local lfs = require "filesystem.local"
local sha1 = require "hash".sha1
local serialize = import_package "ant.serialize".stringify
local datalist = require "datalist"
local config = require "config"
local vfs = require "vfs"
local compile = require "compile".compile

local ResourceCompiler = {
    model = "editor.model.convert",
    glb = "editor.model.glb",
    texture = "editor.texture.convert",
    png = "editor.texture.png",
    sc = "editor.fx.convert",
}

for ext, compiler in pairs(ResourceCompiler) do
    local cfg = config.get(ext)
    cfg.binpath = lfs.path(vfs.repopath()) / ".build" / ext
    cfg.compiler = compiler
end

local function get_filename(pathname)
    pathname = pathname:lower()
    local filename = pathname:match "[/]?([^/]*)$"
    return filename.."_"..sha1(pathname)
end

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

local function do_compile(cfg, setting, input, output)
    lfs.create_directories(output)
    local ok, deps = require(cfg.compiler)(input, output, setting, function (path)
        return absolute_path(input, path)
    end)
    if not ok then
        local err = deps
        error("compile failed: " .. input:string() .. "\n" .. err)
    end
    create_depfile(output / ".dep", deps or {})
end

local function parseUrl(url)
    local path, arguments = url:match "^([^?]*)%?(.*)$"
    local setting = {}
    arguments:gsub("([^=&]*)=([^=&]*)", function(k ,v)
        setting[k] = v
    end)
    return path, setting, arguments
end

local function compile_localfile(folder, fileurl)
    local file, setting, arguments = parseUrl(fileurl)
    local hash = sha1(arguments):sub(1,7)
    local ext = file:match "[^/]%.([%w*?_%-]*)$"
    local cfg = config.get(ext)
    local input = lfs.absolute(folder / file)
    local keystring = input:string():lower()
    local output = cfg.binpath / get_filename(keystring) / hash
    if not lfs.exists(output) or not do_build(output) then
        do_compile(cfg, setting, input, output)
        writefile(output / ".setting", serialize(setting))
        writefile(output / ".arguments", arguments)
    end
    return output
end

local function compile_virtualfile(url)
    local path, setting, arguments = parseUrl(url)
    local input = fs.path(path):localpath()
    local file = input:filename():string()
    local hash = sha1(arguments):sub(1,7)
    local ext = file:match "[^/]%.([%w*?_%-]*)$"
    local cfg = config.get(ext)
    local keystring = input:string():lower() 
    local output = cfg.binpath / get_filename(keystring) / hash
    if not lfs.exists(output) or not do_build(output) then
        if setting.varying_path then
            setting.varying_path = fs.path(setting.varying_path):localpath():string()
        end
        do_compile(cfg, setting, input, output)
        writefile(output / ".setting", serialize(setting))
        writefile(output / ".arguments", arguments)
    end
    return output
end

function vfs.resource(urllst)
    local url = urllst[1]
    if #urllst == 1 then
        if url:match "?" then
            return compile_virtualfile(url)
        end
        return fs.path(url):localpath()
    end
    local folder = compile_virtualfile(url)
    for i = 2, #urllst do
        if urllst[i]:match "?" then
            folder = compile_localfile(folder, urllst[i])
        else
            folder = folder /urllst[i]
        end
    end
    return folder
end

vfs.sync.resource = vfs.resource
vfs.async.resource = vfs.resource
