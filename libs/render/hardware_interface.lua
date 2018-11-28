local hw = {}
hw.__index = hw

local caps = nil
local renderertype = nil
function hw.get_caps()
    return assert(caps)
end

function hw.init(nwh, fb_w, fb_h, fetchlog, renderer)
	renderertype = renderer or "OPENGL"
	local args = {
        nwh = nwh,
        width = fb_w,
        height = fb_h,
		renderer = renderertype,
        getlog = fetchlog or true,
	}

	local bgfx = require "bgfx"
	-- todo: bgfx.init support other flags : reset , maxFrameLatency, maxEncoders, debug, profile, etc.
	bgfx.init(args)

    bgfx.reset(fb_w, fb_h, "v")

	assert(caps == nil)
    caps = bgfx.get_caps()
end

local shadertypes = {
	NOOP       = "d3d9",
	DIRECT3D9  = "d3d9",
	DIRECT3D11 = "d3d11",
	DIRECT3D12 = "d3d11",
	GNM        = "pssl",
	METAL      = "metal",
	OPENGL     = "glsl",
	OPENGLES   = "essl",
	VULKAN     = "spirv",
}

function hw.shader_type()
	if caps then
		return assert(shadertypes[caps.rendererType])
	end
end

function hw.default_shader_type(plat)
	if plat then
		local PLAT = plat:upper()
		local platform_shadertypes = {
			-- all using "glsl"
			WINDOWS = "glsl",	
			OSX = "glsl",		
		}

		local shadertype = platform_shadertypes[PLAT]
		if shadertype then
			return shadertype
		end
	end

	return "glsl"
end

return hw