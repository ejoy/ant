local resource = {}

local FILELIST = {}	-- filename -> { filename =, meta = , object = , proxy =, source = }
local LOADER
local UNLOADER

-- util functions
local function format_error(format, ...)
	error(format:format(...))
end

local function readonly(self, key)
	format_error("Resource %s is readonly, try to write %s", self, key)
end

local function not_in_memory(self, key)
	if key == nil then
		format_error("Resource %s is not in memory")
	elseif key == "_data" then
		return nil
	else
		format_error("Resource %s is not in memory, try to read %s", self, key)
	end
end

local function data_pairs(self)
	return pairs(self._data)
end

local function data_len(self)
	return #self._data
end

local function data_mt(robj)
	return {
		filename = robj.filename,
		__index = robj.object,
		__newindex = readonly,
		__tostring = robj.meta.__tostring,
		__pairs = data_pairs,
		__len = data_len,
	}
end

-- function loader(data) -> table
function resource.register(loader, unloader)
	assert(LOADER == nil)
	assert(type(loader) == "function")
	LOADER = loader
	UNLOADER = unloader
end

local function get_file_object(filename)
	local robj = FILELIST[filename]
	if not robj then
		-- never load this file
		robj = {
			filename = filename,
			meta = {
				filename = filename,
				__index = not_in_memory,
				__pairs = not_in_memory,
				__len = not_in_memory,
				__newindex = readonly,
				__tostring = function (self)
					return filename
				end,
			},
			proxy = { _data = false },
		}
		setmetatable(robj.proxy, robj.meta)
		FILELIST[filename] = robj
	end
	return robj
end

local function load_resource(robj, filename, data)
	if not LOADER then
		format_error("Unknown loader")
	end
	robj.object = LOADER(filename, data)
	robj.proxy._data = robj.object
	setmetatable(robj.proxy, data_mt(robj))
end

function resource.load(filename, data, lazyload)
	local robj = get_file_object(filename)
	if lazyload then
		robj.source = data
		-- auto loader
		robj.meta.__index = function (self, key)
			load_resource(robj, robj.filename, robj.source)
			local data = self._data
			if not data then
				format_error("%s is invalid", self)
			else
				return data[key]
			end
		end
		robj.meta.__pairs = function (self)
			load_resource(robj, robj.filename, robj.source)
			return pairs(self._data)
		end
		robj.meta.__len = function (self)
			load_resource(robj, robj.filename, robj.source)
			return #self._data
		end
		-- lazy load
		return
	else
		robj.source = nil
		robj.meta.__index = not_in_memory
		robj.meta.__pairs = not_in_memory
		robj.meta.__len = not_in_memory
	end
	if robj.object then
		-- already in memory
		return
	end
	load_resource(robj, filename, data)
end

function resource.unload(filename)
	local robj = FILELIST[filename]
	if robj.object == nil then
		-- not in memory
		return
	end
	setmetatable(robj.proxy, robj.meta)

	if UNLOADER then
		UNLOADER(robj.filename, robj.source, robj.object)
	end
	robj.object = nil
end

function resource.reload(filename, data)
	local robj = get_file_object(filename)
	if robj.object then
		resource.unload(filename)
	end
	if robj.source then
		robj.source = data
	end
	load_resource(robj, filename, data)
end

function resource.proxy(filename)
	return get_file_object(filename).proxy
end

-- reture "runtime" / "data" / "ref"
-- result : { filenames, ... }
function resource.status(proxy, result)
	local data = proxy._data
	if data == nil then
		return "runtime"
	end
	if data then
		return "data"
	end
	if result then
		local filename = getmetatable(proxy).filename
		if not result[filename] then
			result[filename] = true
			result[#result+1] = filename
		end
	end
	return "ref"
end

-- returns a touched function if enable is true, this function would returns true if the filename is used
function resource.monitor(filename, enable)
	local robj = get_file_object(filename)
	local object = robj.object
	if enable then
		if not object then
			format_error("%s not in memory", filename)
		end
		local touch = false
		local meta = getmetatable(robj.proxy)
		function meta:__index(key)
			touch = true
			return self._data[key]
		end
		function meta:__pairs(key)
			touch = true
			return pairs(self._data)
		end
		function meta:__len(key)
			touch = true
			return #self._data
		end
		return function() return touch end
	elseif object == nil then
		-- already unload
		return
	else
		-- disable
		local meta = getmetatable(robj.proxy)
		meta.__index = robj.proxy._data
		meta.__pairs = data_pairs
		meta.__len = data_len
	end
end

function resource.edit(obj)
	local data = obj._data
	if not data then
	  pairs(obj)  -- trigger lazyload
	  return obj._data
	else
	  return data
	end
  end
  
return resource

