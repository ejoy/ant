local window = require "window"

local inputmgr = import_package "ant.inputmgr"
local assetutil = import_package "ant.asset".util
local renderpkg = import_package "ant.render"
local argument = import_package "ant.argument"
local fs = require "filesystem"
local thread = require "thread"
local imgui = require "imgui"
local imgui_ant = require "imgui.ant"
imgui = setmetatable(imgui_ant,{__index=imgui})
local platform = require "platform"
local keymap = inputmgr.keymap
local viewidmgr = renderpkg.viewidmgr
local fbmgr = renderpkg.fbmgr
local rhwi = renderpkg.hardware_interface
local font = imgui.font
local Font = platform.font
local imguiIO = imgui.IO
local debug_traceback = debug.traceback
local thread_sleep = thread.sleep

local LOGERROR = __ANT_RUNTIME__ and log.error or print
local debug_update = __ANT_RUNTIME__ and require 'runtime.debug'

local callback = {}

local conifg
local world
local world_update

local ui_viewid = viewidmgr.generate "ui"

local function imgui_resize(width, height)
	local xdpi, ydpi = rhwi.dpi()
	local xscale = math.floor(xdpi/96.0+0.5)
	local yscale = math.floor(ydpi/96.0+0.5)
	imgui.resize(width/xscale, height/yscale, xscale, yscale)
end

function callback.init(nwh, context, width, height)
	imgui.create(nwh)
	rhwi.init {
		nwh = nwh,
		context = context,
		width = width,
		height = height,
	}
	imgui.viewid(ui_viewid)
	local imgui_font = assetutil.create_shader_program_from_file(fs.path "/pkg/ant.imguibase/shader/font.fx").shader
	imgui.font_program(
		imgui_font.prog,
		imgui_font.uniforms.s_tex.handle
	)
	local imgui_image = assetutil.create_shader_program_from_file(fs.path "/pkg/ant.imguibase/shader/image.fx").shader
	imgui.image_program(
		imgui_image.prog,
        imgui_image.uniforms.s_tex.handle
	)
	imgui_resize(width, height)
	imgui.keymap(window.keymap)
	window.set_ime(imgui.ime_handle())
	if platform.OS == "Windows" then
		font.Create { { Font "黑体" ,     18, "\x20\x00\xFF\xFF\x00"} }
	elseif platform.OS == "macOS" then
		font.Create { { Font "华文细黑" , 18, "\x20\x00\xFF\xFF\x00"} }
	else -- iOS
		font.Create { { Font "Heiti SC" , 18, "\x20\x00\xFF\xFF\x00"} }
	end

	local su = import_package "ant.scene".util
	world = su.start_new_world(width, height, conifg)
	world_update = su.loop(world)
end

function callback.mouse_wheel(x, y, delta)
	imgui.mouse_wheel(x, y, delta)
	if not imguiIO.WantCaptureMouse then
		world:pub {"mouse_wheel", delta, x, y}
	end
end

function callback.mouse(x, y, what, state)
	imgui.mouse(x, y, what, state)
	if not imguiIO.WantCaptureMouse then
		world:pub {"mouse", inputmgr.translate_mouse_button(what), inputmgr.translate_mouse_state(state), x, y}
	end
end

local touchid

function callback.touch(x, y, id, state)
	if state == 1 then
		if not touchid then
			touchid = id
			imgui.mouse(x, y, 1, state)
		end
	elseif state == 2 then
		if touchid == id then
			imgui.mouse(x, y, 1, state)
		end
	elseif state == 3 then
		if touchid == id then
			imgui.mouse(x, y, 1, state)
			touchid = nil
		end
	end
	if not imguiIO.WantCaptureMouse then
		world:pub {"touch", inputmgr.translate_mouse_state(state), id, x, y }
	end
end

function callback.keyboard(key, press, state)
	imgui.keyboard(key, press, state)
	if not imguiIO.WantCaptureKeyboard then
		world:pub {"keyboard", keymap[key], press, inputmgr.translate_key_state(state)}
	end
end

callback.char = imgui.input_char

function callback.size(width,height,_)
	imgui_resize(width,height)
	world:pub {"resize", width, height}
	rhwi.reset(nil, width, height)
end

function callback.exit()
	imgui.destroy()
	rhwi.shutdown()
    print "exit"
end

function callback.update()
	if debug_update then debug_update() end
	if world_update then
		world_update()
		rhwi.frame()
	end
end

local function dispatch(ok, CMD, ...)
	if not ok then
		local ok, err = xpcall(callback.update, debug_traceback)
		if not ok then
			LOGERROR(err)
			if err:find("interrupted!", 1, true) then
				dispatch(true, 'exit')
				window.exit()
				return false
			end
		end
		thread_sleep(0)
		return true
	end
	local f = callback[CMD]
	if f then
		local ok, err = xpcall(f, debug_traceback, ...)
		if not ok then
			LOGERROR(err)
		end
	end
	return CMD ~= 'exit'
end

local function run()
	local window = require "common.window"
	while dispatch(window.recvmsg()) do
	end
end

local function windowMode()
	local window = require "common.window"
	window.create(run, 1024, 768, "Hello")
end

local function savebmp(name, width, height, pitch, data)
	if not name then
		return
	end
	local size = pitch * height
	local patternBITMAPFILEHEADER <const> = "<c2I4I2I2I4"
	local patternBITMAPINFOHEADER <const> = "<I4i4i4I2I2I4I4i4i4I4I4"
	local f = assert(io.open(name, "wb"))
	f:write(patternBITMAPFILEHEADER:pack(
		--[[BITMAPFILEHEADER::bfType         ]]   "BM"
		--[[BITMAPFILEHEADER::bfSize         ]] , patternBITMAPFILEHEADER:packsize() + patternBITMAPINFOHEADER:packsize() + size
		--[[BITMAPFILEHEADER::bfReserved1    ]] , 0
		--[[BITMAPFILEHEADER::bfReserved2    ]] , 0
		--[[BITMAPFILEHEADER::bfOffBits      ]] , patternBITMAPFILEHEADER:packsize() + patternBITMAPINFOHEADER:packsize()
	))
	f:write(patternBITMAPINFOHEADER:pack(
		--[[BITMAPINFOHEADER::biSize         ]]   patternBITMAPINFOHEADER:packsize()
		--[[BITMAPINFOHEADER::biWidth        ]] , width
		--[[BITMAPINFOHEADER::biHeight       ]] , -height
		--[[BITMAPINFOHEADER::biPlanes       ]] , 1
		--[[BITMAPINFOHEADER::biBitCount     ]] , 32 --TODO
		--[[BITMAPINFOHEADER::biCompression  ]] , 0
		--[[BITMAPINFOHEADER::biSizeImage    ]] , size
		--[[BITMAPINFOHEADER::biXPelsPerMeter]] , 0
		--[[BITMAPINFOHEADER::biYPelsPerMeter]] , 0
		--[[BITMAPINFOHEADER::biClrUsed      ]] , 0
		--[[BITMAPINFOHEADER::biClrImportant ]] , 0
	))
	f:write(data)
	f:close()
end

local function screenshot(name)
	savebmp(name, renderpkg.util.screen_capture(world, true))
	--local bgfx = require "bgfx"
	--bgfx.request_screenshot(nil, name)
	--bgfx.frame()
	--bgfx.frame()
	--savebmp(bgfx.get_screenshot())
end

local function headlessMode()
	callback.init(nil, nil, 1024, 768)
	if debug_update then debug_update() end
	if world_update then world_update() end
	screenshot(type(argument.headless) == "string" and  argument.headless or "test.bmp")
	callback.exit()
end

local function start(cfg)
	conifg = cfg
	if argument.headless then
		return headlessMode()
	end
	return windowMode()
end

return {
	start = start,
}
