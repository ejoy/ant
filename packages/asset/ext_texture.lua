local bgfx = require "bgfx"
local assetutil= require "util"
local ru = import_package "ant.render".util

local function texture_load(bin, texpath, info)
	local h = bgfx.create_texture(bin, info)
	bgfx.set_name(h, texpath)
	return h
end

return {
	loader = function (filename)
		local tex, binary = assetutil.parse_embed_file(filename)
		local sampler = tex.sampler
		local flag = ru.generate_sampler_flag(sampler)
		
		local handle = texture_load(assert(binary), tex.path, flag)
		return {handle=handle, sampler=ru.fill_default_sampler(sampler)}
	end,
	unloader = function (res)
		bgfx.destroy(assert(res.handle))
		res.handle = nil
	end
}