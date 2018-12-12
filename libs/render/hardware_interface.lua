local hw = {}
hw.__index = hw

local caps = nil
function hw.get_caps()
    return assert(caps)
end

function hw.init(args)
	local bgfx = require "bgfx"
	assert(args.renderer == nil)
	args.getlog = args.getlog or true
	bgfx.init(args)
	bgfx.reset(args.width, args.height, "v")
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

function hw.shutdown()
	bgfx.shutdown()
end

return hw