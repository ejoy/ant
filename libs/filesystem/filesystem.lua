local winfile =  require "winfile"
local memoryfile = require "memoryfile"
local packfile_open = require "packfile.openfile"
local packfile_exist = require "packfile.existfile"

local memopen = memoryfile.open

local filesystem = {
	file = {
		loadfile = winfile.loadfile,
		dofile = winfile.dofile,
		open = packfile_open,
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

os.remove = winfile.remove
os.rename = winfile.rename
loadfile = wrapper "loadfile"
dofile = wrapper "dofile"
io.open = wrapper "open"
os.execute = winfile.execute
os.getenv = winfile.getenv
os.popen = winfile.popen

winfile.exist = packfile_exist

return winfile
