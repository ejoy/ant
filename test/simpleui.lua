dofile "libs/init.lua"

local bgfx = require "bgfx"
local rhwi = require "render.hardware_interface"
local sm = require "render.resources.shader_mgr"
local task = require "editor.task"
local nk = require "bgfx.nuklear"

local canvas = iup.canvas {}

local miandlg = iup.dialog {
	canvas,
	title = "simpleui",
	size = "HALFxHALF",
}

local UI_VIEW = 0

local ctx = {}
local function mainloop()
	nk.windowBegin( "Test","Test Window", 0, 0, 400, 60,
		"border", "movable", "title", "scalable")
	nk.windowEnd()
	nk.update()
	bgfx.frame()
end

local function init(canvas, fbw, fbh)
	rhwi.init(iup.GetAttributeData(canvas,"HWND"), fbw, fbh)

	nk.init {
		view = UI_VIEW,
		width = fbw,
		height = fbh,
		decl = bgfx.vertex_decl {
			{ "POSITION", 2, "FLOAT" },
			{ "TEXCOORD0", 2, "FLOAT" },
			{ "COLOR0", 4, "UINT8", true },
		},
		texture = "s_texColor",
		prog = sm.programLoad("ui/vs_nuklear_texture.sc","ui/fs_nuklear_texture.sc")
	}
	task.loop(mainloop)
end

function canvas:resize_cb(w,h)
	if init then
		init(self, w, h)
		init = nil
	else
		nk.resize(w,h)
	end
	bgfx.reset(w,h, "v")
	ctx.width = w
	ctx.height = h
end

function canvas:action(x,y)
	mainloop()
end

function canvas:keypress_cb(key, press)
	if key ==  iup.K_F1 and press == 1 then
		ctx.debug = not ctx.debug
		bgfx.set_debug( ctx.debug and "S" or "")
	end
end

miandlg:showxy(iup.CENTER,iup.CENTER)
miandlg.usersize = nil

iup.MainLoop()
iup.Close()
