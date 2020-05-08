local imgui       = require "imgui.ant"
local renderpkg   = import_package "ant.render"
local assetmgr    = import_package "ant.asset"
local viewidmgr   = renderpkg.viewidmgr
local rhwi        = renderpkg.hwi
local window      = require "window"
local platform    = require "platform"
local inputmgr    = require "inputmgr"
local font        = imgui.font
local Font        = platform.font
local context     = nil
local cb          = nil
local message     = {}
local initialized = false
local debug_traceback = debug.traceback
local LOGERROR        = __ANT_RUNTIME__ and log.error or print
local debug_update    = __ANT_RUNTIME__ and require 'runtime.debug'

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
	context = imgui.CreateContext(rhwi.native_window())
	imgui.push_context(context)
	imgui.ant.viewid(viewidmgr.get "uieditor")
	local imgui_font = assetmgr.load "/pkg/ant.imguibase/shader/font.fx".shader
	imgui.ant.font_program(
		imgui_font.prog,
		imgui_font.uniforms.s_tex.handle
	)
	local imgui_image = assetmgr.load "/pkg/ant.imguibase/shader/image.fx".shader
	imgui.ant.image_program(
		imgui_image.prog,
        imgui_image.uniforms.s_tex.handle
	)
    inputmgr.init_keymap(imgui)
	window.set_ime(imgui.ime_handle())
	if platform.OS == "Windows" then
		font.Create {
			{ Font "Segoe UI Emoji" , 18, glyphRanges { 0x23E0, 0x329F, 0x1F000, 0x1FA9F }},
			{ Font "黑体" , 18, glyphRanges { 0x0020, 0xFFFF }},
		}
	elseif platform.OS == "macOS" then
		font.Create { { Font "华文细黑" , 18, glyphRanges { 0x0020, 0xFFFF }} }
	else -- iOS
		font.Create { { Font "Heiti SC" , 18, glyphRanges { 0x0020, 0xFFFF }} }
	end
	imgui.pop_context()
end

local function imgui_resize(width, height)
	local xdpi, ydpi = rhwi.dpi()
	local xscale = math.floor(xdpi/96.0+0.5)
	local yscale = math.floor(ydpi/96.0+0.5)
	imgui.resize(width/xscale, height/yscale, xscale, yscale)
end

local function imgui_start()
end

local function imgui_end()
end

function message.init(nwh, context, width, height)
	rhwi.init {
		nwh = nwh,
		context = context,
		width = width,
		height = height,
	}
    imgui_init()
	cb.init()
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
message.char = imgui.input_char
function message.dropfiles(filelst)
	cb.dropfiles(filelst)
end
function message.size(width,height,_)
	imgui.push_context(context)
	imgui_resize(width, height)
	imgui.pop_context()
	rhwi.reset(nil, width, height)
end
function message.exit()
    imgui.DestroyContext()
	rhwi.shutdown()
    print "exit"
end
function message.update()
    if debug_update then debug_update() end
	if initialized then
		local delta = timer_delta()
		imgui.push_context(context)
		imgui.begin_frame(delta * 1000)
        cb.update(delta)
		imgui.end_frame()
		imgui.pop_context()
        rhwi.frame()
    end
end

local function dispatch(CMD, ...)
	local f = message[CMD]
	if f then
		local ok, err = xpcall(f, debug_traceback, ...)
		if not ok then
			LOGERROR(err)
		end
	end
end

local function start(callback)
    cb = callback
    window.create(dispatch, 1024, 768)
    window.mainloop(true)
end

return {
	start = start,
}
