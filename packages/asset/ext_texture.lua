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
	local w, h = c.width, c.height
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
	local v = c.value

	fill_mem_texture_info(c, ti)
	local m = bgfx.memory_buffer(c.mem_format, v)
	return bgfx.create_texture2d(c.width, c.height, false, 1, c.format, c.flag, m)
end

local function loader(filename)
	local config = datalist.parse(readfile(cr.compile(filename .. "|main.cfg")))
	local ti = {}
	local h
	if config.value then
		h = create_mem_texture(config, ti)
	else
		local texfiledata = readfile(cr.compile(filename .. "|main.bin"))
		h = bgfx.create_texture(texfiledata, config.flag, ti)

		-- local img = require "image"
		-- local m = bgfx.memory_buffer(texfiledata)
		-- local texinfo = img.parse(m)

		-- local imgdata = texfiledata	--TODO: cr.compile "main.bin" should be image data
		-- if texinfo.cubeMap then
		-- 	assert(texinfo.width == texinfo.height)
		-- 	bgfx.create_texturecube(texinfo.width, texinfo.numMips ~= 0, texinfo.numLayers, texinfo.format, config.flag, imgdata)
		-- elseif texinfo.depth == 0 then
		-- 	bgfx.create_texture2d(texinfo.width, texinfo.height, texinfo.numMips ~= 0, texinfo.numLayers, texinfo.format, config.flag, imgdata)
		-- else
		-- 	assert(texinfo.depth > 0)
		--	error "not support 3d texture right now"
		-- 	--bgfx.create_texture3d(texinfo.width, texinfo.height, texinfo.depth, texinfo.numMips ~= 0, texinfo.numLayers, texinfo.format, config.flag, imgdata)
		-- end
	end


	
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
