local imgui       = require "imgui.ant"
local renderpkg   = import_package "ant.render"
local assetmgr    = import_package "ant.asset"
local viewidmgr   = renderpkg.viewidmgr
local rhwi        = renderpkg.hwi
local window      = require "window"
local platform    = require "platform"
local inputmgr    = require "inputmgr"
local bgfx        = require "bgfx"
local font        = imgui.font
local Font        = platform.font
local context     = nil
local cb          = nil
local viewid      = nil
local message     = {}
local initialized = false
local debug_traceback = debug.traceback

local _timer = require "platform.timer"
local _time_counter = _timer.counter
local _time_freq    = _timer.frequency() / 1000
local _timer_previous
local _timer_current = _time_counter() / _time_freq
local _timer_delta
local function timer_delta()
	_timer_previous = _timer_current
	_timer_current = _time_counter() / _time_freq
	_timer_delta = _timer_current - _timer_previous
	return _timer_delta
end

local function glyphRanges(t)
	assert(#t % 2 == 0)
	local s = {}
	for i = 1, #t do
		s[#s+1] = ("<I4"):pack(t[i])
	end
	s[#s+1] = "\x00\x00\x00"
	return table.concat(s)
end

local function imgui_init()
	viewid = viewidmgr.get "uieditor"
	context = imgui.CreateContext(rhwi.native_window())
	imgui.ant.viewid(viewid)
	local imgui_font = assetmgr.load_fx {
		fs = "/pkg/ant.imguibase/shader/fs_imgui_font.sc",
		vs = "/pkg/ant.imguibase/shader/vs_imgui_font.sc",
	}
	imgui.ant.font_program(
		imgui_font.prog,
		imgui_font.uniforms[1].handle
	)
	local imgui_image = assetmgr.load_fx {
		fs = "/pkg/ant.imguibase/shader/fs_imgui_image.sc",
		vs = "/pkg/ant.imguibase/shader/vs_imgui_image.sc",
	}
	imgui.ant.image_program(
		imgui_image.prog,
        imgui_image.uniforms[1].handle
	)
    inputmgr.init_keymap(imgui)
	window.set_ime(imgui.ime_handle())
	if platform.OS == "Windows" then
		font.Create {
			--{ Font "Segoe UI Emoji" , 18, glyphRanges { 0x23E0, 0x329F, 0x1F000, 0x1FA9F }},
			{ Font "黑体" , 18, glyphRanges { 0x0020, 0xFFFF }},
		}
	elseif platform.OS == "macOS" then
		font.Create { { Font "华文细黑" , 18, glyphRanges { 0x0020, 0xFFFF }} }
	else -- iOS
		font.Create { { Font "Heiti SC" , 18, glyphRanges { 0x0020, 0xFFFF }} }
	end
end

local function imgui_resize(width, height)
	local xdpi, ydpi = rhwi.dpi()
	local xscale = math.floor(xdpi/96.0+0.5)
	local yscale = math.floor(ydpi/96.0+0.5)
	imgui.resize(width/xscale, height/yscale, xscale, yscale)
end

function message.init(nwh, context, width, height)
	rhwi.init {
		nwh = nwh,
		context = context,
		width = width,
		height = height,
	}
    imgui_init()
	cb.init(width, height)
    initialized = true
end

function message.mouse_wheel(x, y, delta)
    imgui.mouse_wheel(x, y, delta)
	cb.mouse_wheel(x, y, delta)
end
function message.mouse(x, y, what, state)
    imgui.mouse(x, y, what, state)
	cb.mouse(x, y, what, state)
end
function message.keyboard(key, press, state)
    imgui.keyboard(key, press, state)
	cb.keyboard(key, press, state)
end
--message.char = imgui.input_char
function message.char(...)
	imgui.input_char(...)
	cb.char(...)
end
function message.dropfiles(filelst)
	cb.dropfiles(filelst)
end
function message.size(width,height,_)
	imgui_resize(width, height)
	cb.size(width, height)
	rhwi.reset(nil, width, height)
end
function message.exit()
    imgui.DestroyContext()
	rhwi.shutdown()
    print "exit"
end
function message.update()
	if initialized then
		bgfx.set_view_clear(viewid, "CD", 0x000000FF, 1, 0)
		local delta = timer_delta()
		imgui.begin_frame(delta / 1000)
        cb.update(delta)
		imgui.end_frame()
        rhwi.frame()
    end
end

local function dispatch(CMD, ...)
	local f = message[CMD]
	if f then
		local ok, err = xpcall(f, debug_traceback, ...)
		if not ok then
			print(err)
		end
	end
end

local function start(w, h, callback)
    cb = callback
    window.create(dispatch, w, h)
    window.mainloop(true)
end

local function get_context()
    return context
end

return {
	start = start,
	get_context = get_context,
}
