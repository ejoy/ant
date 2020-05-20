local fs = require "filesystem"
local lfs = require "filesystem.local"
local vfs = require "vfs"
local sha1 = require "hash".sha1
local datalist = require "datalist"
local stringify = import_package "ant.serialize".stringify
local cache = {}
local link = {}

local function init(ext, compiler)
    link[ext] = {
        compiler = compiler,
        config = {},
    }
end

init("fx",      require "fx.compile")
init("glb",     require "model.convert")
init("texture", require "texture.convert")

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

local function set_config(ext, config)
    local config_string = stringify(config)
    local info = link[ext]
    if not info then
        error("invalid type: " .. ext)
    end
    local hash = sha1(config_string):sub(1,7)
    local cfg = info.config[hash]
    if cfg then
        return cfg
    end
    cfg = {}
    if not info.default then
        info.default = cfg
    end
    info.config[hash] = cfg
    local root = vfs.repo()._root
    cfg.compiler = info.compiler
    cfg.config = config
    cfg.hash = hash
    cfg.binpath = root / ".build" / ext / (info.name.."_"..hash)
    cfg.deppath = root / ".dep" / ext / (info.name.."_"..hash)
    lfs.create_directories(cfg.binpath)
    lfs.create_directories(cfg.deppath)
    writefile(cfg.binpath / ".config", config_string)
    return cfg
end

local function register(ext, name, config)
    local info = link[ext]
    if not info then
        error("invalid type: " .. ext)
    end
    info.name = name
    return set_config(ext, config)
end

local function copytable(a, b)
    for k,v in pairs(b) do
        if type(v) == "table" then
            local ak = a[k]
            if ak == nil then
                local t = {}
                copytable(t, v)
                a[k] = t
            else
                assert(type(ak) == "table")
                copytable(ak, v)
            end
        else
            a[k] = v
        end
    end
end

local function mergetable(a, b)
    local t = {}
    copytable(t, a)
    copytable(t, b)
    return t
end

local function get_config(ext, config)
    local info = link[ext]
    if not info then
        return
    end
    local defalut = assert(info.default)
    if not config then
        return defalut
    end
    return set_config(ext, mergetable(config, defalut.config))
end

local function do_build(cfg, pathname)
    local deppath = cfg.deppath / (get_filename(pathname) .. ".dep")
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
        w[#w+1] = ("{%d, %q}"):format(lfs.last_write_time(file:localpath()), file:localpath():string())
    end
    writefile(filename, table.concat(w, "\n"))
end

local function do_compile(cfg, pathname, outpath)
    lfs.create_directory(outpath)
    local ok, err, deps = cfg.compiler(cfg.config, pathname,  outpath, function (path)
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
    create_depfile(cfg.deppath / (get_filename(pathname) .. ".dep"), deps)
end

local function compile(filename, config)
    local pathname = fs.path(filename)
    local ext = pathname:extension():string():sub(2):lower()
    local pathstring = pathname:string()
    local cfg = get_config(ext, config)
    if not cfg then
        return pathstring
    end
    local keystring = cfg.hash .. pathstring
    local cachepath = cache[keystring]
    if cachepath then
        return cachepath
    end
    local outpath = cfg.binpath / get_filename(pathname)
    if not do_build(cfg, pathname) or not lfs.exists(outpath) then
        do_compile(cfg, pathname, outpath)
    end
    cache[keystring] = outpath
    return outpath
end

return {
    register = register,
    compile = compile,
}
