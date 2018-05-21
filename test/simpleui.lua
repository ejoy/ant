dofile "libs/init.lua"

local bgfx = require "bgfx"
local rhwi = require "render.hardware_interface"
local sm = require "render.resources.shader_mgr"
local task = require "editor.task"
local nk = require "bgfx.nuklear"
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local nkmsg = require "inputmgr.nuklear"

local canvas = iup.canvas {}

local miandlg = iup.dialog {
	canvas,
	title = "simpleui",
	size = "HALFxHALF",
}

local input_queue = inputmgr.queue(mapiup, canvas)

local UI_VIEW = 0


local function save_ppm(filename, data, width, height, pitch)
	local f = assert(io.open(filename, "wb"))
	f:write(string.format("P3\n%d %d\n255\n",width, height))
	local line = 0
	for i = 0, height-1 do
		for j = 0, width-1 do
			local r,g,b,a = string.unpack("BBBB",data,i*pitch+j*4+1)
			f:write(r," ",g," ",b," ")
			line = line + 1
			if line > 8 then
				f:write "\n"
				line = 0
			end
		end
	end
	f:close()
end

function save_screenshot(filename)
	local name , width, height, pitch, data = bgfx.get_screenshot()
	if name then
		local size = #data
		if size < width * height * 4 then
			-- not RGBA
			return
		end
		print("Save screenshot to ", filename)
		save_ppm(filename, data, width, height, pitch)
	end
end


local ctx = {}
local message = {}
local function mainloop()
	save_screenshot "screenshot.ppm"
	for _, msg,x,y,z,w,u in pairs(input_queue) do
		nkmsg.push(message, msg, x,y,z,w,u)
	end
	nk.input(message)
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
		state = bgfx.make_state {
			WRITE_MASK = "RGBA",
			BLEND = "ALPHA",
		},
		prog = sm.programLoad("ui/vs_nuklear_texture.sc","ui/fs_nuklear_texture.sc")
	}

	bgfx.set_view_clear(UI_VIEW, "C", 0x303030ff, 1, 0)

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
	if key == iup.K_F12 and press == 1 then
		bgfx.request_screenshot()
	end
end

miandlg:showxy(iup.CENTER,iup.CENTER)
miandlg.usersize = nil

iup.MainLoop()
iup.Close()
