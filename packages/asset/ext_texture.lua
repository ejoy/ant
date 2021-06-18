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

local function fill_mem_texture_info(c, ti)
	local w, h = c.size[1], c.size[2]
	ti.width, ti.height = w, h
	ti.format = c.format
	ti.mipmap = false
	ti.depth = 1
	ti.numLayers = 1
	ti.cubemap = false
	ti.storageSize = w*h*4
	ti.numMips = 1
	ti.bitsPerPixel = 32
end

local function create_mem_texture(c, ti)
	local fmt = c.format
	local s = c.size
	local w, h = s[1], s[2]
	local v = c.value
	assert(fmt == "RGBA8")

	fill_mem_texture_info(c, ti)
	local m = bgfx.memory_buffer("bbbb", v)
	return bgfx.create_texture2d(w, h, false, 1, fmt, c.flag, m)
end

local function loader(filename)
	local config = datalist.parse(readfile(cr.compile(filename .. "|main.cfg")))
	local ti = {}
	local h = config.value and 
		create_mem_texture(config, ti) or
		bgfx.create_texture(readfile(cr.compile(filename .. "|main.bin")), config.flag, ti)
	
	bgfx.set_name(h, config.name)
	return {
		handle = h,
		texinfo = ti,
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
