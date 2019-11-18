local hw = {}
hw.__index = hw

local platform = require "platform"
local bgfx     = require "bgfx"
local setting  = require "setting"

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
	assert(nwh,"handle is nil")
	local bgfx = require "bgfx"
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
end

function hw.init(args)
	bgfx_init(args)
	local vfs = require "vfs"
	vfs.identity(".fx",      hw.identity(), "")
	vfs.identity(".mesh",    hw.identity(), "")
	vfs.identity(".texture", hw.identity(), "")
	setting.init()
end

function hw.dpi()
	return platform.dpi(nwh)
end

function hw.native_window()
	return nwh
end

function hw.reset(t, w_, h_)
	if t then flags = t end
	local bgfx = require "bgfx"
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
	local bgfx = require "bgfx"
	bgfx.reset(w, h, get_flags())
end

function hw.remove_reset_flag(flag)
	local f = flag:sub(1,1)
	if flags[f] ~= nil then
		return
	end
	flags[f] = nil
	local bgfx = require "bgfx"
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
	local bgfx = require "bgfx"
	bgfx.shutdown()
end

function hw.identity()
	local plat = platform.OS
	local plat_depend_info = " "
	if plat == "iOS" then
		local iosinfo = import_package "ant.ios"
		plat_depend_info = iosinfo.cpu
	end
	return string.format(".%s[%s]_%s", plat, plat_depend_info, caps.rendererType):lower()
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