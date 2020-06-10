local fs = require "filesystem"
local lfs = require "filesystem.local"
local vfs = require "vfs"
local sha1 = require "hash".sha1
local datalist = require "datalist"
local stringify = import_package "ant.serialize".stringify
local cache = {}
local info = {config = {}}
local c = require "compile"

local function split(str)
    local r = {}
    str:gsub('[^|]*', function (w) r[#r+1] = w end)
    return r
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

local function set_config(config)
    local config_string = stringify(config)
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
    cfg.config = config
    cfg.hash = hash
    cfg.binpath = root / ".build" / "fx" / (info.name.."_"..hash)
    lfs.create_directories(cfg.binpath)
    writefile(cfg.binpath / ".config", config_string)
    return cfg
end

local function register(name, config)
    info.name = name
    return set_config(config)
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

local function get_config(config)
    local defalut = assert(info.default)
    if not config then
        return defalut
    end
    return set_config(mergetable(config, defalut.config))
end

local function do_build(output)
    local depfile = output / ".dep"
    if not lfs.exists(depfile) then
        return
    end
	for _, dep in ipairs(readconfig(depfile)) do
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
        local path = lfs.path(file)
        w[#w+1] = ("{%d, %q}"):format(lfs.last_write_time(path), lfs.absolute(path):string())
    end
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
    local ok, err, deps = require "fx.compile" (cfg.config, input, output, function (path)
        return absolute_path(input, path)
    end)
    if not ok then
        error("compile failed: " .. input:string() .. "\n\n" .. err)
    end
    create_depfile(output / ".dep", deps)
end

local function clean_file(input)
    local cfg = get_config()
    if not cfg then
        return input
    end
    local keystring = input:string() .. "_" .. cfg.hash
    local cachepath = cache[keystring]
    if cachepath then
        cache[keystring] = nil
        lfs.remove_all(cachepath)
    else
        lfs.remove_all(cfg.binpath / get_filename(input))
    end
end

local function compile_file(input, config)
    local cfg = get_config(config)
    if not cfg then
        assert(lfs.exists(input))
        return input
    end
    local keystring = input:string() .. "_" .. cfg.hash
    local cachepath = cache[keystring]
    if cachepath then
        return cachepath
    end
    local output = cfg.binpath / get_filename(input)
    if not lfs.exists(output) or not do_build(output) then
        do_compile(cfg, input, output)
    end
    cache[keystring] = output
    return output
end

local function clean(pathstring)
    local pathlst = split(pathstring)
    local path = fs.path(pathlst[1]):localpath()
    for i = 2, #pathlst do
        path = c.compile_file(path) / pathlst[i]
    end
    return clean_file(path)
end

local function compile(pathstring, config)
    local pathlst = split(pathstring)
    local path = fs.path(pathlst[1]):localpath()
    for i = 2, #pathlst do
        path = c.compile_file(path) / pathlst[i]
    end
    return compile_file(path, config)
end

return {
    register = register,
    compile = compile,
    clean = clean,
}
