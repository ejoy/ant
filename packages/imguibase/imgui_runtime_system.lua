local ecs = ...
local world = ecs.world

local imgui       = require "imgui.ant"
local renderpkg   = import_package "ant.render"
local fbmgr       = renderpkg.fbmgr
local viewidmgr   = renderpkg.viewidmgr
local rhwi        = renderpkg.hwi
local window      = require "window"
local assetmgr    = import_package "ant.asset"
local platform    = require "platform"
local inputmgr    = require "inputmgr"
local imguiIO     = imgui.IO
local font        = imgui.font
local Font        = platform.font
local timer       = world:interface "ant.timer|timer"
local eventResize = world:sub {"resize"}

local imgui_sys = ecs.system "imgui_system"

local function hookEvent()
	local touchid
	world:signal_hook("mouse_wheel", function(x, y, delta)
		imgui.mouse_wheel(x, y, delta)
		return imguiIO.WantCaptureMouse
	end)
	world:signal_hook("mouse", function(x, y, what, state)
		imgui.mouse(x, y, what, state)
		return imguiIO.WantCaptureMouse
	end)
	world:signal_hook("touch", function(x, y, id, state)
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
		return imguiIO.WantCaptureMouse
	end)
	world:signal_hook("keyboard", function(key, press, state)
		imgui.keyboard(key, press, state)
		return imguiIO.WantCaptureKeyboard
	end)
	world:signal_hook("char", imgui.input_char)
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

function imgui_sys:init()
	hookEvent()

	world.imgui_context = imgui.CreateContext(rhwi.native_window())
	imgui.ant.viewid(viewidmgr.generate "ui")
	local imgui_font = assetmgr.load_fx_file "/pkg/ant.imguibase/shader/font.fx"
	imgui.ant.font_program(
		imgui_font.prog,
		imgui_font.uniforms[1].handle
	)
	local imgui_image = assetmgr.load_fx_file "/pkg/ant.imguibase/shader/image.fx"
	imgui.ant.image_program(
		imgui_image.prog,
        imgui_image.uniforms[1].handle
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
end

function imgui_sys:exit()
    imgui.DestroyContext()
end

function imgui_sys:post_init()
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

function imgui_sys:ui_start()
	for _,w, h in eventResize:unpack() do
		imgui_resize(w, h)
	end
    local delta = timer.delta()
    imgui.begin_frame(delta * 1000)
end

-- --test
-- function m:ui_update()
-- 	local wndflags = imgui.flags.Window { "NoTitleBar", "NoResize", "NoScrollbar" }
-- 	imgui.windows.SetNextWindowPos(0,0)
-- 	imgui.windows.Begin("Testdsasd", wndflags)
-- 	if imgui.widget.Button "rotate" then
--         print("rotate")
--     end
--     imgui.windows.End()

-- end
local bgfx = require "bgfx"
function imgui_sys:ui_end()
    imgui.end_frame()
	local vid = imgui.ant.viewid()
	local fb = fbmgr.get(fbmgr.get_fb_idx(vid))
	if fb then
		bgfx.set_view_frame_buffer(vid, fb.handle)
	end
end
