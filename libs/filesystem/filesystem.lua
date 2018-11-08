--luacheck: globals enable_packfile
local winfile =  require "winfile"
local memoryfile = require "memoryfile"

local memopen = memoryfile.open

local filesystem = {
	file = {
		loadfile = _G.loadfile,
		dofile = _G.dofile,
		open = _G.io.open,
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

loadfile = wrapper "loadfile"
dofile = wrapper "dofile"
io.open = wrapper "open"

return winfile
