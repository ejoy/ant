local fs = require "filesystem.cpp"
local datalist = require "datalist"
local stringify = require "packages.serialize.v2.stringify".map

local function rawtable(filepath)
	local env = {}
	local r = assert(loadfile(filepath:string(), "t", env))
	r()
	return env
end

local function writefile(filepath, data)
    local f = assert(io.open(filepath:string(), "wb"))
    f:write(data)
    f:close()
end

local function isDatalist(filepath)
	local f = assert(io.open(filepath:string(), "rb"))
	local data = f:read "a"
	f:close()
	return pcall(datalist.parse, data)
end

local function each_dir(dir, cb)
    for file in dir:list_directory() do
        if fs.is_directory(file) then
            each_dir(file, cb)
        else
            cb(file)
        end
    end
end

local allow = {
    fx = true,
    material = true,
    mesh = true,
    pbrm = true,
    state = true,
    terrain = true,
    texture = true,
}

local function convert(file)
    local ext = file:extension():string():lower():sub(2)
    if allow[ext] and not isDatalist(file) then
        print("Convert", file)
        writefile(file, stringify(rawtable(file)))
    end
end

local function convert_dir(dir)
    each_dir(fs.path(dir), convert)
end

convert_dir "test"
convert_dir "tools"
convert_dir "packages"
