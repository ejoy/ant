local fs = require "filesystem"
local lfs = require "filesystem.local"
local sha1 = require "hash".sha1
local stringify = require "fx.stringify"
local serialize = import_package "ant.serialize".stringify
local link = {
    glb = {},
    texture = {},
    png = {}
}

local function set_identity(ext, identity)
    local cfg = link[ext]
    if not cfg then
        error("invalid type: " .. ext)
    end
    cfg.setting = {
        identity = identity
    }
    cfg.hash = sha1(stringify(cfg.setting)):sub(1,7)
end

local function split(str)
    local r = {}
    str:gsub('[^|]*', function (w) r[#r+1] = w end)
    return r
end

if __ANT_RUNTIME__ then
    local function compile(pathstring)
        local pathlst = split(pathstring)
        if #pathlst == 1 then
            return fs.path(pathlst[1]):localpath()
        end
        local path = fs.path(pathlst[1])
        for i = 2, #pathlst do
            local ext = path:extension():string():sub(2):lower()
            local cfg = link[ext]
            if cfg then
                path = (path / cfg.hash / pathlst[i]):localpath()
            else
                path = path:localpath() / pathlst[i]
            end
        end
        return path
    end
    return {
        set_identity = set_identity,
        compile = compile,
    }
end

local datalist = require "datalist"

local compiler = {
    glb = "model.convert",
    texture = "texture.convert",
    png = "png.convert"
}

for ext, cfg in pairs(link) do
    cfg.binpath = fs.path "":localpath() / ".build" / ext
    cfg.compiler = compiler[ext]
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
    lfs.create_directories(output)
    local ok, err = require(cfg.compiler)(input, output, cfg.setting.identity, function (path)
        return absolute_path(input, path)
    end)
    if not ok then
        error("compile failed: " .. input:string() .. "\n" .. err)
    end
    create_depfile(output / ".dep", input)
    writefile(output / ".setting", serialize(cfg.setting))
end

local function compile_file(input)
    local ext = input:extension():string():sub(2):lower()
    local cfg = link[ext]
    if not cfg then
        return input
    end
    local keystring = lfs.absolute(input):string():lower()
    local output = cfg.binpath / get_filename(keystring) / cfg.hash
    if not lfs.exists(output) or not do_build(output) then
        do_compile(cfg, input, output)
    end
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

local function compile(pathstring)
    return compile_file(compile_path(pathstring))
end

return {
    set_identity = set_identity,
    compile = compile,
}
