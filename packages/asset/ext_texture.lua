
local assetutil= require "util"

local renderpkg = import_package "ant.render"
local ru 		= renderpkg.util
local rhwi 		= renderpkg.hardware_interface

local bgfx 		= require "bgfx"
local platform 	= require "platform"
local OS		= platform.OS:lower()


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
		if tex.colorspace == "sRGB" then
			local caps = rhwi.get_caps()
			local texformat = assert(assetutil.which_format(OS, tex))
			local fmtinfo = assert(caps.formats[texformat])
			if fmtinfo["2D_SRGB"] then
				flag = flag .. 'Sg'	-- S for 'colorspace' and g/l for 'gamma'/'linear'
			else
				log.warn(string.format("texture:%s, is sRGB space, but hardware not support sRGB", filename:string()))
			end
		end
		local handle = texture_load(assert(binary), tex.path, flag)
		return {handle=handle, sampler=ru.fill_default_sampler(sampler)}, 0
	end,
	unloader = function (res)
		bgfx.destroy(assert(res.handle))
		res.handle = nil
	end
}