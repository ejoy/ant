local hw = {}

local platform = require "bee.platform"
local bgfx     = require "bgfx"

local default_renderer <const> = {
	windows = "DIRECT3D11",
	macos = "METAL",
	ios = "METAL",
	android = "VULKAN",
	linux = "VULKAN",
}

local function check_renderer(renderer)
	if renderer == nil then
		return default_renderer[platform.os]
	end
	if platform.os == "ios" and renderer ~= "METAL" then
		assert(false, 'iOS platform context layer is select before bgfx renderer created \
			the default layter is metal, if we need to test OpenGLES on iOS platform \
			we need to change the context layter to OpenGLES')
	end
	return renderer
end

local init_args
local native_window

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

function hw.init(args)
	local LOG_NONE  <const> = 1
	local LOG_ERROR <const> = 2
	local LOG_WARN  <const> = 3
	local LOG_TRACE <const> = 4

	init_args = {
		nwh      = args.nwh,
		ndt      = args.ndt,
		context  = args.context,
		width    = args.width,
		height   = args.height,
		renderer = check_renderer(args.renderer),
		loglevel = args.loglevel or LOG_WARN,
		reset    = args.reset or cvt_flags {
			s = true,
		},
		--debug = true,
	}
	bgfx.init(init_args)
end

function hw.set_native_window(window)
	native_window = window
end

function hw.native_window()
	return native_window
end

local DEBUG_FLAGS<const> = {
	IFH = "I",
	WIREFRAME = "W",
	STATS = "S",
	TEXT = "T",
	PROFILER = "P",
}
function hw.set_debug(t)
	local f = ""
	for _, v in pairs(t) do
		f = f .. assert(DEBUG_FLAGS[v])
	end
	bgfx.set_debug(f)
end

function hw.set_profie(enable)
	if enable then
		bgfx.set_debug "TP"
	else
		bgfx.set_debug ""
	end
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

local ltask = require "ltask"
local ServiceBgfxMain = ltask.queryservice "ant.hwi|bgfx"
function hw.init_bgfx()
    for _, name in ipairs(ltask.call(ServiceBgfxMain, "CALL")) do
        bgfx[name] = function (...)
            return ltask.call(ServiceBgfxMain, name, ...)
        end
    end
    for _, name in ipairs(ltask.call(ServiceBgfxMain, "SEND")) do
        bgfx[name] = function (...)
            ltask.send(ServiceBgfxMain, name, ...)
        end
    end
end

function hw.viewid_get(name)
	return ltask.call(ServiceBgfxMain, "viewid_get", name)
end

function hw.viewid_generate(...)
	return ltask.call(ServiceBgfxMain, "viewid_generate", ...)
end

return hw
