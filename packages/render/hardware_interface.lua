local hw = {}
hw.__index = hw

local platform = require "platform"
local platos = platform.OS

local caps = nil
function hw.get_caps()
    return assert(caps)
end

local function check_renderer(renderer)
	if renderer == nil then
		return hw.default_renderer()
	end

	if platos == "iOS" and renderer ~= "METAL" then
		assert(false, 'iOS platform context layer is select before bgfx renderer created \
			the default layter is metal, if we need to test OpenGLES on iOS platform \
			we need to change the context layter to OpenGLES')
	end

	return renderer
end

function hw.init(args)
	local bgfx = require "bgfx"
	args.renderer = check_renderer(args.renderer)
	args.getlog = args.getlog or true
	if args.reset == nil then
		args.reset = "vm4"
	end
	
	bgfx.init(args)
	assert(caps == nil)
	caps = bgfx.get_caps()

	local vfs = require "vfs"
	vfs.identity(hw.identity())
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

local platform_relates = {
	WINDOWS = {
		shadertype="d3d11",
		renderer="DIRECT3D11",
	},
	OSX = {
		shadertype="metal",
		renderer="METAL",
	},
	IOS = {
		shadertype="metal",
		renderer="METAL",
	},
	ANDROID = {
		shadertype="spirv",
		renderer="VULKAN",
	},
}

function hw.default_shader_type(plat)
	if plat then
		local PLAT = plat:upper()
		local pi = platform_relates[PLAT]
		if pi then
			return pi.shadertype
		end
	end

	return "glsl"
end

function hw.default_renderer(plat)
	plat = plat or platos
	local PLAT=plat:upper()
	local pi = platform_relates[PLAT]
	if pi then
		if PLAT == "IOS" then
			assert(pi.renderer == "METAL")
		end
		return pi.renderer
	end
end

function hw.shutdown()
	local bgfx = require "bgfx"
	bgfx.shutdown()
end

function hw.identity()
	return platos .. "-" .. assert(hw.shader_type())
end

return hw