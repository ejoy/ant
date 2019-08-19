local util = {}; util.__index = util
local fs = require "filesystem.local"

function util.list_files(subpath, filter, excludes)
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

function util.raw_table(filepath)
	local env = {}
	local r = assert(fs.loadfile(filepath, "t", env))
	r()
	return env
end

return util