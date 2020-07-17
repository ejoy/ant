local fs = require "filesystem"
local lfs = require "filesystem.local"
local vfs = require "vfs"
local sha1 = require "hash".sha1
local datalist = require "datalist"
local cache = {}
local link = {}

local function init(ext, compiler)
    link[ext] = {
        compiler = compiler,
    }
end

init("glb",     "model.convert")
init("texture", "texture.convert")

local function split(str)
    local r = {}
    str:gsub('[^|]*', function (w) r[#r+1] = w end)
    return r
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

local function register(ext, identity)
    local info = link[ext]
    if not info then
        error("invalid type: " .. ext)
    end
    local root = vfs.repo()._root
    info.compiler = info.compiler
    if identity then
        info.identity = identity
        info.binpath = root / ".build" / ext / identity
    else
        info.binpath = root / ".build" / ext
    end
    lfs.create_directories(info.binpath)
    return info
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

local function create_depfile(filename, input)
    local w = {}
    local function insert_dep(file)
        if lfs.exists(file) then
            w[#w+1] = ("{%d, %q}"):format(lfs.last_write_time(file), lfs.absolute(file):string())
        else
            w[#w+1] = ("{0, %q}"):format(lfs.absolute(file):string())
        end
    end
    insert_dep(input)
    insert_dep(input..".patch")
    writefile(filename, table.concat(w, "\n"))
end

local function absolute_path(base, path)
	if path:sub(1,1) == "/" then
		return fs.path(path):localpath()
	end
	return lfs.absolute(base:parent_path() / (path:match "^%./(.+)$" or path))
end

local function do_compile(cfg, input, output)
    lfs.create_directory(output)
    local ok, err = require(cfg.compiler)(input, output, cfg.identity, function (path)
        return absolute_path(input, path)
    end)
    if not ok then
        error("compile failed: " .. input:string() .. "\n" .. err)
    end
    create_depfile(output / ".dep", input)
end

local function clean_file(input)
    local ext = input:extension():string():sub(2):lower()
    local cfg = link[ext]
    if not cfg then
        return input
    end
    local keystring = input:string()
    local cachepath = cache[keystring]
    if cachepath then
        cache[keystring] = nil
        lfs.remove_all(cachepath)
    else
        lfs.remove_all(cfg.binpath / get_filename(input:string()))
    end
end

local function compile_file(input)
    local ext = input:extension():string():sub(2):lower()
    local cfg = link[ext]
    if not cfg then
        if not lfs.exists(input) then
            error(tostring(input) .. " not exist")
        end
        assert(lfs.exists(input))
        return input
    end
    local keystring = lfs.absolute(input):string():lower()
    local cachepath = cache[keystring]
    if cachepath then
        return cachepath
    end
    local output = cfg.binpath / get_filename(keystring)
    if not lfs.exists(output) or not do_build(output) then
        do_compile(cfg, input, output)
    end
    cache[keystring] = output
    return output
end

local function compile_path(pathstring)
    local pathlst = split(pathstring)
    local path = fs.path(pathlst[1]):localpath()
    for i = 2, #pathlst do
        path = compile_file(path) / pathlst[i]
    end
    return path
end

local function clean(pathstring)
    return clean_file(compile_path(pathstring))
end

local function compile(pathstring)
    return compile_file(compile_path(pathstring))
end

return {
    register = register,
    compile = compile,
    clean = clean,
}
