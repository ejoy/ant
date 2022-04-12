local hw = {}
hw.__index = hw

local platform = require "platform"
local bgfx     = require "bgfx"

local math3d   = require "math3d"

local caps = nil
function hw.get_caps()
	if caps == nil then
    	caps = bgfx.get_caps()
	end
	return caps
end

local function check_renderer(renderer)
	if renderer == nil then
		return hw.default_renderer()
	end

	if platform.OS == "iOS" and renderer ~= "METAL" then
		assert(false, 'iOS platform context layer is select before bgfx renderer created \
			the default layter is metal, if we need to test OpenGLES on iOS platform \
			we need to change the context layter to OpenGLES')
	end

	return renderer
end

local init_args

local function cvt_flags(flags)
	local t = {}
	for f, v in pairs(flags) do
		if v == true then
			t[#t+1] = f
		else
			t[#t+1] = f..v
		end
	end	
	return table.concat(t)
end

local function bgfx_init(args)
	local fb = args.framebuffer
	local LOG_NONE  <const> = 1
	local LOG_ERROR <const> = 2
	local LOG_WARN  <const> = 3
	local LOG_TRACE <const> = 4

	init_args = {
		nwh 	= args.nwh,
		width 	= fb.width,
		height 	= fb.height,
		renderer= check_renderer(args.renderer),
		loglevel= args.loglevel or LOG_WARN,
		reset 	= args.reset or cvt_flags{
			-- v = true,
			--m = 4,
			s = true,
		}
	}
	bgfx.init(init_args)
end

function hw.init(args)
	bgfx_init(args)
	hw.get_caps()
	math3d.set_homogeneous_depth(caps.homogeneousDepth)
	math3d.set_origin_bottom_left(caps.originBottomLeft)
end

function hw.dpi()
	return platform.dpi(init_args.nwh)
end

function hw.native_window()
	return init_args.nwh
end

function hw.screen_size()
	return init_args.width, init_args.height
end

function hw.reset(t, w, h)
	if t then
		init_args.reset = cvt_flags(t)
	end
	if w then
		init_args.width = w
	end

	if h then
		init_args.height = h
	end

	bgfx.reset(init_args.width, init_args.height, init_args.reset)
end

local platform_relates = {
	WINDOWS = {
		renderer="DIRECT3D11",
	},
	OSX = {
		renderer="METAL",
	},
	IOS = {
		renderer="METAL",
	},
	ANDROID = {
		renderer="VULKAN",
	},
}

function hw.default_renderer(plat)
	plat = plat or platform.OS
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
	caps = nil
	bgfx.shutdown()
end

hw.frames = nil
function hw.frame()
	hw.frames = bgfx.encoder_frame()
	return hw.frames
end

return hw