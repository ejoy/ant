local cr        = import_package "ant.compile_resource"
local bgfx 		= require "bgfx"
local lfs       = require "filesystem.local"
local datalist  = require "datalist"

local function readfile(filename)
	local f = assert(lfs.open(filename, "rb"))
	local data = f:read "a"
	f:close()
	return data
end

local mem_formats <const> = {
	RGBA8 = "bbbb",
	RGBA32F = "ffff",
}

local function create_mem_texture(c)
	local ti = c.info
	local v = c.value
	local memfmt = assert(mem_formats[ti.format], "not support memory texture format")
	local m = bgfx.memory_buffer(memfmt, v)
	if ti.cubeMap then
		assert(ti.width == ti.height)
		return bgfx.create_texturecube(ti.width, ti.numMips ~= 0, ti.numLayers, ti.format, c.flag, m)
	elseif ti.depth == 1 then
		return bgfx.create_texture2d(ti.width, ti.height, ti.numMips ~= 0, ti.numLayers, ti.format, c.flag, m)
	else
		assert(ti.depth > 1)
		error "not support 3d texture right now"
		return bgfx.create_texture3d(ti.width, ti.height, ti.depth, ti.numMips ~= 0, ti.numLayers, ti.format, c.flag, m)
	end
end

local function loader(filename)
	local config = datalist.parse(readfile(cr.compile(filename .. "|main.cfg")))
	local h
	if config.value then
		h = create_mem_texture(config)
	else
		local texfiledata = readfile(cr.compile(filename .. "|main.bin"))
		h = bgfx.create_texture(texfiledata, config.flag)
	end
	bgfx.set_name(h, config.name)
	return {
		handle = h,
		texinfo = config.info,
		sampler = config.sampler
	}
end

local function unloader(res)
	bgfx.destroy(assert(res.handle))
end

return {
    loader = loader,
    unloader = unloader,
}
