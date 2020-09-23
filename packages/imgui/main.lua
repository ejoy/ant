local imgui       = require "imgui"
local renderpkg   = import_package "ant.render"
local viewidmgr   = renderpkg.viewidmgr
local assetmgr    = import_package "ant.asset"
local rhwi        = renderpkg.hwi
local platform    = require "platform"
local font        = imgui.font
local Font        = platform.font
local cb          = nil
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

function message.init(nwh, context, width, height)
	rhwi.init {
		nwh = nwh,
		context = context,
		width = width,
		height = height,
	}
	cb.init(width, height)
    initialized = true
end

function message.dropfiles(filelst)
	cb.dropfiles(filelst)
end
function message.size(width,height,_)
	cb.size(width, height)
	rhwi.reset(nil, width, height)
end
function message.exit()
    imgui.Destroy()
	rhwi.shutdown()
    print "exit"
end

local mouse = {}
local keyboard = {}

local function updateIO()
	local io = imgui.IO
	if not io.WantCaptureMouse then
		if io.MouseWheel ~= 0 then
			cb.mouse_wheel(io.MousePos[1], io.MousePos[2], io.MouseWheel)
		end
		for i = 1, 3 do
			if io.MouseClicked[i] then
				mouse[i] = true
				cb.mouse(io.MousePos[1], io.MousePos[2], i, 1)
			end
			if io.MouseReleased[i] then
				mouse[i] = nil
				cb.mouse(io.MousePos[1], io.MousePos[2], i, 3)
			end
			if mouse[i] and not io.MouseClicked[i] then
				cb.mouse(io.MousePos[1], io.MousePos[2], i, 2)
			end
		end
	end
	if not io.WantCaptureKeyboard then
		for code in pairs(io.KeysPressed) do
			keyboard[code] = true
			cb.keyboard(code, 1, io.KeyMods)
		end
		for code in pairs(io.KeysReleased) do
			keyboard[code] = nil
			cb.keyboard(code, 0, io.KeyMods)
		end
		for code in pairs(keyboard) do
			if not io.KeysPressed[code] then
				cb.keyboard(code, 2, io.KeyMods)
			end
		end
	end
end

function message.update()
	if initialized then
		local delta = timer_delta()
		imgui.NewFrame(delta / 1000)
		updateIO()
        cb.update(delta)
		imgui.Render()
        rhwi.frame()
    end
end
function message.viewid()
	return viewidmgr.generate("imgui", viewidmgr.get "uieditor")
end

local function dispatch(CMD, ...)
	local f = message[CMD]
	if f then
		local ok, err = xpcall(f, debug_traceback, ...)
		if ok then
			return err
		else
			print(err)
		end
	end
end

local function start(w, h, callback)
    cb = callback
	imgui.Create(dispatch, w, h)
	local imgui_font = assetmgr.load_fx {
		fs = "/pkg/ant.imgui/shader/fs_imgui_font.sc",
		vs = "/pkg/ant.imgui/shader/vs_imgui_font.sc",
	}
	imgui.SetFontProgram(
		imgui_font.prog,
		imgui_font.uniforms[1].handle
	)
	local imgui_image = assetmgr.load_fx {
		fs = "/pkg/ant.imgui/shader/fs_imgui_image.sc",
		vs = "/pkg/ant.imgui/shader/vs_imgui_image.sc",
	}
	imgui.SetImageProgram(
		imgui_image.prog,
		imgui_image.uniforms[1].handle
	)
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
    imgui.MainLoop()
end

return {
	start = start,
}
