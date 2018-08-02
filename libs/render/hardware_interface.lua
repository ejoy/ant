local bgfx = require "bgfx"

local hw = {}
hw.__index = hw

local caps = nil

function hw.get_caps()
    return assert(caps)
end

function hw.init(nwh, fb_w, fb_h)
	local args = {
        nwh = nwh,
        width = fb_w,
		height = fb_h,
		getlog = true,
	}
	bgfx.set_platform_data(args)
	bgfx.init(args)

    bgfx.reset(fb_w, fb_h, "v")

	assert(caps == nil)
    caps = bgfx.get_caps()    
end

return hw