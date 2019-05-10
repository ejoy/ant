local native = require "window.native"
local window = require "window"
local bgfx = require "bgfx"
local imgui = require "bgfx.imgui"
local widget = imgui.widget
local enum = imgui.enum

local callback = {}
local attribs = {}

function callback.init(nwh, context, width, height)
	bgfx.init {
		nwh = nwh,
		context = context,
	--	renderer = "DIRECT3D9",
	--	renderer = "OPENGL",
		width = width,
		height = height,
	--	reset = "v",
	}

	attribs.font_size = 18
	attribs.mx = 0
	attribs.my = 0
	attribs.button1 = false
	attribs.button2 = false
	attribs.button3 = false
	attribs.scroll = 0
	attribs.width = width
	attribs.height = height
	attribs.viewid = 255

	imgui.create(attribs.font_size)
	imgui.keymap(native.keymap)

	bgfx.set_view_rect(0, 0, 0, width, height)
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
--	bgfx.set_debug "ST"
end

function callback.size(width,height,type)
	attribs.width = width
	attribs.height = height
	bgfx.reset(width, height, "")
	bgfx.set_view_rect(0, 0, 0, width, height)
end

function callback.char(code)
	imgui.input_char(code)
end

function callback.error(err)
	print(err)
end

function callback.mouse_move(x,y)
	attribs.mx = x
	attribs.my = y
end

function callback.mouse_wheel(x,y,delta)
	attribs.scroll = delta
	attribs.mx = x
	attribs.my = y
end

function callback.mouse_click(x, y, what, pressed)
	if what == 0 then
		attribs.button1 = pressed
	elseif what == 1 then
		attribs.button2 = pressed
	elseif what == 2 then
		attribs.button3 = pressed
	end
	attribs.mx = x
	attribs.my = y
end

function callback.keyboard(key, press, state)
	imgui.key_state(key, press, state)
end

local editbox = {
	label = "Edit",
	flags = enum.InputTextFlags { "CallbackCharFilter", "CallbackHistory", "CallbackCompletion" },
}

function editbox:filter(c)
	if c == 65 then
		-- filter 'A'
		return
	end
	return c
end

local t = 0
function editbox:up()
	t = t - 1
	return tostring(t)
end

function editbox:down()
	t = t + 1
	return tostring(t)
end

function editbox:tab(pos)
	local text = tostring(self.text)
	return text:sub(1, pos)
end

local editfloat = {
	0,
	step = 0.1,
	step_fast = 10,
}

local function update_ui()
	widget.Button "Test"
	widget.SmallButton "Small"
	change, checked = widget.Checkbox("Checkbox", checked)
	if change then
		print("Click Checkbox", checked)
	end
	if widget.InputText(editbox) then
		print(editbox.text)
	end
	widget.InputFloat(editfloat)
end

function callback.update()
	imgui.begin_frame(
		attribs.mx,
		attribs.my,
		attribs.button1,
		attribs.button2,
		attribs.button3,
		attribs.scroll,
		attribs.width,
		attribs.height,
		attribs.viewid
	)
	update_ui()
	imgui.end_frame()

	bgfx.touch(0)

--	bgfx.dbg_text_clear()
--	bgfx.dbg_text_print(0, 1, 0xf, "Color can be changed with ANSI \x1b[9;me\x1b[10;ms\x1b[11;mc\x1b[12;ma\x1b[13;mp\x1b[14;me\x1b[0m code too.");

	bgfx.frame()
end

function callback.exit()
	print("Exit")
	imgui.destroy()
	bgfx.shutdown()
end

window.register(callback)

native.create(1024, 768, "Hello")
native.mainloop()
