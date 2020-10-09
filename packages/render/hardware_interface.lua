local hw = {}
hw.__index = hw

local platform = require "platform"
local bgfx     = require "bgfx"
local bgfxutil = require "bgfx.util"

local math3d   = require "math3d"
local  lfont   = require "font"

local caps = nil
function hw.get_caps()
    return assert(caps)
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

local flags = {}
local w, h
local nwh

local function get_flags()
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
	nwh, w, h = args.nwh, args.width, args.height
	--assert(nwh,"handle is nil")
	
	args.renderer = check_renderer(args.renderer)
	args.getlog = args.getlog or true
	if args.reset == nil then
		flags = {
			-- v = true,
			m = 4,
			s = true,
		}
		args.reset = get_flags()
	end
	
	bgfx.init(args)
	assert(caps == nil)
	caps = bgfx.get_caps()
	math3d.set_homogeneous_depth(caps.homogeneousDepth)
	math3d.homogeneous_depth = caps.homogeneousDepth
	math3d.set_origin_bottom_left(caps.originBottomLeft)
	math3d.origin_bottom_left = caps.originBottomLeft

	lfont.init(bgfxutil.update_char_texture)
end

function hw.init(args)
	bgfx_init(args)
    local os = platform.OS
    local renderer = hw.get_caps().rendererType
	import_package "ant.compile_resource".set_identity((os.."_"..renderer):lower())
end

function hw.dpi()
	return platform.dpi(nwh)
end

function hw.native_window()
	return nwh
end

function hw.screen_size()
	return w, h
end

function hw.reset(t, w_, h_)
	if t then flags = t end
	w = w_ or w
	h = h_ or h
	bgfx.reset(w, h, get_flags())
end

function hw.add_reset_flag(flag)
	local f = flag:sub(1,1)
	local v = flag:sub(2) or true
	if flags[f] == v then
		return
	end
	flags[f] = v
	bgfx.reset(w, h, get_flags())
end

function hw.remove_reset_flag(flag)
	local f = flag:sub(1,1)
	if flags[f] ~= nil then
		return
	end
	flags[f] = nil
	bgfx.reset(w, h, get_flags())
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
local _ui_dirty = false

function hw.ui_frame()
	_ui_dirty = true
end
function hw.frame()
	hw.frames = bgfx.frame()
	_ui_dirty = false
	return hw.frames
end

function hw.on_update_end()
	if _ui_dirty then
		hw.frame()
	end
end

return hw