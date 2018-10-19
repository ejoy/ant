local winfile =  require "winfile"
local memoryfile = require "memoryfile"
local packfile_open = require "packfile.openfile"

local memopen = memoryfile.open

local filesystem = {
	file = {
		loadfile = winfile.loadfile or _G.loadfile,
		dofile = winfile.dofile or _G.dofile,
		open = function (...)
			if packfile_open then
				if enable_pack_framework == nil or enable_pack_framework() then
					return packfile_open(...)
				end
			end
		
			return winfile.open(...)
		end
		,
	},
	mem = {
		loadfile = function(filename, ...)
			local f, err = memopen(filename, "rb")
			if not f then
				return nil, err
			end
			local src = f:read "a"
			f:close()
			return load(src, "@mem://" .. filename, ...)
		end,
		dofile = function(filename)
			local f = assert(memopen(filename, "rb"))
			local src = f:read "a"
			f:close()
			local chunk = assert(load(src, "@mem://" .. filename))
			return chunk()
		end,
		open = memopen,
	},
}

local function split_filename(fn)
	local fs, name = fn:match "^(%w+)://(.+)"
	if fs then
		return fs, name
	else
		return "file", fn
	end
end

local function wrapper(apiname)
	return function(filename, ...)
		local fs, name = split_filename(filename)
		local api = filesystem[fs]
		if api == nil then
			error("No filesystem " .. fs)
		end
		return api[apiname](name, ...)
	end
end

os.remove = winfile.remove or os.remove
os.rename = winfile.rename or os.rename
loadfile = wrapper "loadfile"
dofile = wrapper "dofile"
io.open = wrapper "open"
os.execute = winfile.execute or os.execute
os.getenv = winfile.getenv or os.getenv
os.popen = winfile.popen or os.popen

return winfile
