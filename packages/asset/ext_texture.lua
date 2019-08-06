local bgfx = require "bgfx"
local fs = require "filesystem"
local assetmgr = require "asset"

local ru = import_package "ant.render".util

local function texture_load(filepath, info)
	local f = assert(fs.open(filepath, "rb"))
	local imgdata = f:read "a"
	f:close()
	local h = bgfx.create_texture(imgdata, info)
	bgfx.set_name(h, filepath:string())
	return h
end

return {
	loader = function (filename)
		local tex = assetmgr.get_depiction(filename)
		local texrefpath = fs.path(tex.path)
		if not fs.exists(texrefpath) then
			error(string.format("texture path not found, .texture path:[%s], texture file:[%s]", filename, texrefpath))
		end

		local sampler = tex.sampler
		local flag = ru.generate_sampler_flag(sampler)
		
		local handle = texture_load(texrefpath, flag)
		return {handle=handle, sampler=ru.fill_default_sampler(sampler), path=texrefpath}
	end,
	unloader = function (res)
		local tex = res.handle
		bgfx.destroy(assert(tex.handle))
		tex.handle = nil
		res.handle = nil
	end
}