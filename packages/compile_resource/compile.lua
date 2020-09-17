local fs = require "filesystem"
local lfs = require "filesystem.local"
local sha1 = require "hash".sha1
local datalist = require "datalist"
local link = {
    glb = {
        compiler = "model.convert",
        binpath = fs.path "":localpath() / ".build" / "glb",
        identity = {},
    },
    texture = {
        compiler = "texture.convert",
        binpath = fs.path "":localpath() / ".build" / "texture",
        identity = {},
    },
    png = {
        compiler = "png.convert",
        binpath = fs.path "":localpath() / ".build" / "imgui_png",
        identity = {},
    }
}

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

local function set_identity(ext, identity)
    local cfg = link[ext]
    if not cfg then
        error("invalid type: " .. ext)
    end
    cfg.identity = identity
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
    local ok, err = require(cfg.compiler)(input, output, cfg.identity, function (path)
        return absolute_path(input, path)
    end)
    if not ok then
        error("compile failed: " .. input:string() .. "\n" .. err)
    end
    create_depfile(output / ".dep", input)
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
    local output = cfg.binpath / cfg.identity / get_filename(keystring)
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
