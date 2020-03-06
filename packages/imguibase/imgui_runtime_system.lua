local ecs = ...
local world = ecs.world

local imgui       = require "imgui.ant"
local renderpkg   = import_package "ant.render"
local renderutil  = renderpkg.util
local fbmgr       = renderpkg.fbmgr
local viewidmgr   = renderpkg.viewidmgr
local rhwi        = renderpkg.hwi
local window      = require "window"
local assetutil   = import_package "ant.asset".util
local fs          = require "filesystem"
local platform    = require "platform"
local runtime     = require "runtime"
local imguiIO     = imgui.IO
local font        = imgui.font
local Font        = platform.font
local timer       = world:interface "ant.timer|timer"
local eventResize = world:sub {"resize"}
local context     = nil

local m = ecs.system "imgui_system"

m.require_system "ant.render|render_system"
m.require_interface "ant.timer|timer"

local function replaceImguiCallback(t)
	local l_mouse_wheel = t.mouse_wheel
	local l_mouse = t.mouse
	local l_touch = t.touch
	local l_keyboard = t.keyboard
	function t.mouse_wheel(x, y, delta)
		imgui.mouse_wheel(x, y, delta)
		if not imguiIO.WantCaptureMouse then
			l_mouse_wheel(x, y, delta)
		end
	end
	function t.mouse(x, y, what, state)
		imgui.mouse(x, y, what, state)
		if not imguiIO.WantCaptureMouse then
			l_mouse(x, y, what, state)
		end
	end
	local touchid
	function t.touch(x, y, id, state)
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
			l_touch(x, y, id, state)
		end
	end
	function t.keyboard(key, press, state)
		imgui.keyboard(key, press, state)
		if not imguiIO.WantCaptureKeyboard then
			l_keyboard(key, press, state)
		end
	end
	t.char = imgui.input_char
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

function m:init()
	replaceImguiCallback(runtime.callback)

	context = imgui.CreateContext(rhwi.native_window())
	imgui.ant.viewid(viewidmgr.generate "ui")
	local imgui_font = assetutil.create_shader_program_from_file(fs.path "/pkg/ant.imguibase/shader/font.fx").shader
	imgui.ant.font_program(
		imgui_font.prog,
		imgui_font.uniforms.s_tex.handle
	)
	local imgui_image = assetutil.create_shader_program_from_file(fs.path "/pkg/ant.imguibase/shader/image.fx").shader
	imgui.ant.image_program(
		imgui_image.prog,
        imgui_image.uniforms.s_tex.handle
	)
	imgui.keymap(window.keymap)
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
end

function m:exit()
    imgui.DestroyContext()
end

function m:post_init()
    local main_viewid = assert(viewidmgr.get "main_view")
    local vid = imgui.ant.viewid()
    fbmgr.bind(vid, assert(fbmgr.get_fb_idx(main_viewid)))
end

local function imgui_resize(width, height)
	local xdpi, ydpi = rhwi.dpi()
	local xscale = math.floor(xdpi/96.0+0.5)
	local yscale = math.floor(ydpi/96.0+0.5)
	imgui.resize(width/xscale, height/yscale, xscale, yscale)
end

function m:ui_start()
    imgui.SetCurrentContext(context)
	for _,w, h in eventResize:unpack() do
		imgui_resize(w, h)
	end
    local delta = timer.delta()
    imgui.begin_frame(delta * 1000)
end

function m:ui_end()
    imgui.end_frame()
    local vid = imgui.ant.viewid()
    renderutil.update_frame_buffer_view(vid, fbmgr.get_fb_idx(vid))
end
