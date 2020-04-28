local fs = require "filesystem"
local lfs = require "filesystem.local"
local vfs = require "vfs"
local sha1 = require "hash".sha1
local datalist = require "datalist"
local stringify = import_package "ant.serialize".stringify
local link = {}
local cache = {}

local function get_platname(name, config)
    return name.."_"..sha1(config):sub(1,7)
end

local function get_filename(pathname)
    local stem = pathname:stem():string()
    local parent = pathname:parent_path():string()
    return stem.."_"..sha1(parent)
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

local function register(ext, compiler)
    link[ext] = {
        compiler = compiler
    }
end

local function set_config(ext, name, config)
    config = stringify(config)
    local info = link[ext]
    if not info then
        error("invalid type: " .. ext)
    end
    local root = vfs.repo()._root
    local plathash = get_platname(name, config)
    info.name = name
    info.binpath = root / "_build" / ext / plathash
    info.deppath = root / ".dep" / ext / plathash
	lfs.create_directories(info.binpath)
	lfs.create_directories(info.deppath)
    writefile(info.binpath / ".config", config)
end

local function do_build(ext, pathname)
    local info = link[ext]
    local deppath = info.deppath / (get_filename(pathname) .. ".dep")
    if not lfs.exists(deppath) then
        return
    end
	for _, dep in ipairs(readconfig(deppath)) do
		local timestamp, filename = dep[1], lfs.path(dep[2])
		if not lfs.exists(filename) or timestamp ~= lfs.last_write_time(filename) then
			return
		end
	end
	return true
end

local function create_depfile(filename, deps)
    local w = {}
    for _, file in ipairs(deps) do
        w[#w+1] = ("{%d, %q}"):format(lfs.last_write_time(file), file:string())
    end
    writefile(filename, table.concat(w, "\n"))
end

local function do_compile(ext, pathname, outpath)
    local info = link[ext]
    lfs.create_directory(outpath)
    local ok, err, deps = info.compiler(readconfig(info.binpath / ".config"), pathname,  outpath / "main.index", function (path)
        return fs.path(path):localpath()
    end)
    if not ok then
        error("compile failed: " .. pathname:string() .. "\n" .. err)
    end
    if deps then
        table.insert(deps, 1, pathname)
    else
        deps = {pathname}
    end
    create_depfile(info.deppath / (get_filename(pathname) .. ".dep"), deps)
end

local function compile(pathname)
    local ext = pathname:extension():string():sub(2):lower()
    local pathstring = pathname:string()
    local info = link[ext]
    if not info then
        return pathstring
    end
    local cachepath = cache[pathstring]
    if cachepath then
        return cachepath
    end
    local outpath = info.binpath / get_filename(pathname)
    if not do_build(ext, pathname) or not lfs.exists(outpath) then
        do_compile(ext, pathname, outpath)
    end
    local respath = (outpath / "main.index"):string()
    cache[pathstring] = respath
    return respath
end

return {
    register = register,
    set_config = set_config,
    compile = compile,
}
