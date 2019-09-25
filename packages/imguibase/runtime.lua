local window = require "window"

local inputmgr = import_package "ant.inputmgr"
local assetutil = import_package "ant.asset".util
local renderpkg = import_package "ant.render"
local bgfx = require "bgfx"
local fs = require "filesystem"
local thread = require "thread"
local imgui = require "imgui"
local platform = require "platform"

local keymap = inputmgr.keymap
local viewidmgr = renderpkg.viewidmgr
local rhwi = renderpkg.hardware_interface
local font = imgui.font
local Font = platform.font
local imguiIO = imgui.IO
local debug_traceback = debug.traceback
local thread_sleep = thread.sleep

local LOGERROR = __ANT_RUNTIME__ and log.error or print
local debug_update = __ANT_RUNTIME__ and require 'runtime.debug'

local iq = inputmgr.queue()

local callback = {}

local packages, systems
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
	imgui.viewid(ui_viewid);
	local imgui_font = assetutil.create_shader_program_from_file {
		vs = fs.path "/pkg/ant.imguibase/shader/vs_imgui_font.sc",
		fs = fs.path "/pkg/ant.imguibase/shader/fs_imgui_font.sc",
	}
	imgui.font_program(
		imgui_font.prog,
		imgui_font.uniforms.s_tex.handle
	)
	local imgui_image = assetutil.create_shader_program_from_file {
		vs = fs.path "/pkg/ant.imguibase/shader/vs_imgui_image.sc",
		fs = fs.path "/pkg/ant.imguibase/shader/fs_imgui_image.sc",
	}
	imgui.image_program(
		imgui_image.prog,
		imgui_image.uniforms.s_texColor.handle,
		imgui_image.uniforms.u_imageLodEnabled.handle
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
	world = su.start_new_world(iq, width, height, packages, systems)
	world_update = su.loop(world, {
		update = {"timesystem", "message_system"}
	})
end

function callback.mouse_wheel(x, y, delta)
	imgui.mouse_wheel(x, y, delta)
	if not imguiIO.WantCaptureMouse then
		iq:push("mouse_wheel", x, y, delta)
	end
end

function callback.mouse(x, y, what, state)
	imgui.mouse(x, y, what, state)
	if not imguiIO.WantCaptureMouse then
		iq:push("mouse", x, y, inputmgr.translate_mouse_button(what), inputmgr.translate_mouse_state(state))
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
		iq:push("touch", x, y, id, inputmgr.translate_mouse_state(state))
	end
end

function callback.keyboard(key, press, state)
	imgui.keyboard(key, press, state)
	if not imguiIO.WantCaptureKeyboard then
		iq:push("keyboard", keymap[key], press, inputmgr.translate_key_state(state))
	end 
end

callback.char = imgui.input_char

function callback.size(width,height,_)
	imgui_resize(width,height)
	iq:push("resize", width,height)
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

local function start(m1, m2)
	packages, systems = m1, m2

	local window = require "common.window"
	window.create(run, 1024, 768, "Hello")
end

return {
	start = start,
}
