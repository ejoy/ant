package.path = "./?.lua;engine/?.lua"

local fs = require "filesystem.local"
local datalist = require "datalist"
local stringify = require "packages.serialize.stringify"


local function list_files(subpath, filter, excludes)
	local prefilter = {}
	if type(filter) == "string" then
		for f in filter:gmatch("([.%w]+)") do
			local ext = f:upper()
			prefilter[ext] = true
		end
	end

	local function list_fiels_1(subpath, filter, excludes, files)
		for p in subpath:list_directory() do
			local name = p:filename():string()
			if not excludes[name] then
				if fs.is_directory(p) then
					list_fiels_1(p, filter, excludes, files)
				else
					if type(filter) == "function" then
						if filter(p) then
							files[#files+1] = p
						end
					else
						local fileext = p:extension():string():upper()
						if filter[fileext] then
							files[#files+1] = p
						end
					end
					
				end
			end
		end		
	end

    local files = {}
    list_fiels_1(subpath, prefilter, excludes, files)
    return files
end

local function read_datalist(p)
    local f = fs.open(p)
    if f == nil then
        print("not found file:", p)
        return
    end
    local c = f:read "a"
    f:close()
    return datalist.parse(c)
end

local materialfiles = list_files(fs.current_path() / "packages", ".material", {})

local function which_pkg(p)
    return p:match "/pkg/([^/]+)/"
end

local pkg_to_paths = {
    ["ant.resources"] = fs.current_path() / "packages/resources"
}

local function to_localpath(p)
    local pkgname =  which_pkg(p)
    if pkgname then
        local n = p:gsub("/pkg/[^/]+", pkg_to_paths[pkgname]:string())
        return n
    end
end

local function write_file(p, c)
    local f = fs.open(p, "wb")
    f:write(c)
    f:close()
end

for _, mf in ipairs(materialfiles) do
    local c = read_datalist(mf)
    if type(c.fx) == "string" then
        local fxpath = fs.path(to_localpath(c.fx))
        c.fx = read_datalist(fxpath)
        local s = stringify(c)
        write_file(mf, s)
    end
end

for _, fxfile in ipairs(list_files(fs.current_path() / "packages", ".fx", {})) do
    fs.remove(fxfile)
end