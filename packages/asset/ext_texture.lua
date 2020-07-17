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

local function loader(filename)
	local config = datalist.parse(readfile(cr.compile(filename .. "|main.cfg")))
	local h = bgfx.create_texture(readfile(cr.compile(filename .. "|main.bin")), config.flag)
	bgfx.set_name(h, config.name)
	return {
		handle = h,
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
