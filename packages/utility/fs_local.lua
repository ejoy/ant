local u = {}

local fs = require "filesystem.local"
local platform = require "platform"
local datalist = require "datalist"

function u.datalist(filepath)
	local f = assert(fs.open(filepath, "r"))
	local data = f:read "a"
	f:close()
	return datalist.parse(data)
end

function u.list_files(subpath, filter, excludes, add_path)
	local prefilter = {}
	if type(filter) == "string" then
		for f in filter:gmatch("([.%w]+)") do
			local ext = f:upper()
			prefilter[ext] = true
		end
    end
    
    add_path = add_path or function (p) return p end

	local function list_fiels_1(subpath, filter, excludes, files)
		for p in subpath:list_directory() do
			local name = p:filename():string()
			if not excludes[name] then
				if fs.is_directory(p) then
					list_fiels_1(p, filter, excludes, files)
				else
					if type(filter) == "function" then
						if filter(p) then
							files[#files+1] = add_path(p)
						end
					else
						local fileext = p:extension():string():upper()
						if filter[fileext] then
							files[#files+1] = add_path(p)
						end
					end
				end
			end
		end
	end
    local files = {}
    local excludemap = {}
    for _, e in ipairs(excludes) do
        excludemap[e] = true
    end
    list_fiels_1(subpath, prefilter, excludemap, files)
    return files
end

function u.write_file(filepath, c)
    local f = fs.open(filepath, "wb")
    f:write(c)
    f:close()
end

local BINDIR = fs.current_path() / package.cpath:sub(1,-6)
local TOOLSUFFIX = platform.OS == "OSX" and "" or ".exe"

function u.valid_tool_exe_path(toolname)
    local exepath = BINDIR / (toolname .. TOOLSUFFIX)
    if fs.exists(exepath) then
        return exepath
    end
    error(table.concat({
        "Can't found tools in : ",
        "\t" .. tostring(exepath)
    }, "\n"))
end

return u
