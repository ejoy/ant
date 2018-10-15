local bgfx = require "bgfx"

local hw = {}
hw.__index = hw

local caps = nil

function hw.get_caps()
    return assert(caps)
end

function hw.init(nwh, fb_w, fb_h, fetchlog)
	local args = {
        nwh = nwh,
        width = fb_w,

        height = fb_h,
        getlog = fetchlog or true,
	}
	bgfx.set_platform_data(args)
	-- todo: bgfx.init support other flags : reset , maxFrameLatency, maxEncoders, debug, profile, etc.
	bgfx.init(args)

    bgfx.reset(fb_w, fb_h, "v")

	assert(caps == nil)
    caps = bgfx.get_caps()
end

return hw