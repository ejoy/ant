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
    cfg.arguments = stringify(cfg.setting)
end

local function split(str)
    local r = {}
    str:gsub('[^|]*', function (w) r[#r+1] = w end)
    return r
end

local function compile_path(pathstring, seq)
    local pathlst = split(pathstring)
    local res = {}
    for i = 1, #pathlst - 1 do
        local path = pathlst[i]
        local ext = path:match "[^/]%.([%w*?_%-]*)$"
        local cfg = assert(link[ext], "invalid path")
        res[#res+1] = path
        res[#res+1] = "?"
        res[#res+1] = cfg.arguments
        res[#res+1] = seq
    end
    res[#res+1] = pathlst[#pathlst]
    return table.concat(res)
end

if __ANT_RUNTIME__ then
    local function compile(pathstring)
        return fs.path(compile_path(pathstring, "/")):localpath()
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

local function do_compile(cfg, setting, input, output)
    lfs.create_directories(output)
    local ok, err = require(cfg.compiler)(input, output, setting.identity, function (path)
        return absolute_path(input, path)
    end)
    if not ok then
        error("compile failed: " .. input:string() .. "\n" .. err)
    end
    create_depfile(output / ".dep", input)
end

local function parseUrl(url)
    local path, arguments = url:match "^([^?]*)%?(.*)$"
    local setting = {}
    arguments:gsub("([^=&]*)=([^=&]*)", function(k ,v)
        setting[k] = v
    end)
    return path, setting, arguments
end

local function compile_file(url)
    local path, setting, arguments = parseUrl(url)
    local hash = sha1(arguments):sub(1,7)
    local ext = path:match "[^/]%.([%w*?_%-]*)$"
    local cfg = assert(link[ext], "invalid path")
    local input = fs.path(path):localpath()
    local keystring = lfs.absolute(input):string():lower()
    local output = cfg.binpath / get_filename(keystring) / hash
    if not lfs.exists(output) or not do_build(output) then
        do_compile(cfg, setting, input, output)
        writefile(output / ".setting", serialize(setting))
        writefile(output / ".arguments", arguments)
    end
    return output
end

local function compile(pathstring)
    local urllst = split(compile_path(pathstring, "|"))
    local url = urllst[1]
    if #urllst == 1 then
        return fs.path(url):localpath()
    end
    for i = 2, #urllst do
        url = compile_file(url) .. "/" .. urllst[i]
    end
    return url
end

return {
    set_identity = set_identity,
    compile = compile,
}
