local ecs = ...
local world = ecs.world
local w = world.w

local imgui = require "imgui"
local platform = require "bee.platform"
local rhwi = import_package "ant.hwi"
local assetmgr = import_package "ant.asset"
local PM = require "programan.client"

local m = ecs.system 'imgui_system'

local event = {}

function event.size()
end

function event.dropfiles(files)
end

local viewidcount = 0
local imgui_viewids = {}

for i = 1, 16 do
	imgui_viewids[i] = rhwi.viewid_generate("imgui_eidtor" .. i, "uiruntime")
end

function event.viewid()
	if viewidcount >= #imgui_viewids then
		error(("imgui viewid range exceeded, max count:%d"):format(#imgui_viewids))
	end
	viewidcount = viewidcount + 1
	return imgui_viewids[viewidcount]
end

function m:init()
	imgui.v2.CreateContext(event)
	imgui.v2.InitPlatform(rhwi.native_window())

	local imgui_font = assetmgr.load_material "/pkg/ant.imgui/materials/font.material"
	local imgui_image = assetmgr.load_material "/pkg/ant.imgui/materials/image.material"
	assetmgr.material_mark(imgui_font.fx.prog)
	assetmgr.material_mark(imgui_image.fx.prog)
	imgui.InitRender(
		PM.program_get(imgui_font.fx.prog),
		PM.program_get(imgui_image.fx.prog),
		imgui_font.fx.uniforms.s_tex.handle,
		imgui_image.fx.uniforms.s_tex.handle
	)

	local Font = imgui.font.SystemFont
	local function glyphRanges(t)
		assert(#t % 2 == 0)
		local s = {}
		for i = 1, #t do
			s[#s+1] = ("<I4"):pack(t[i])
		end
		s[#s+1] = "\x00\x00\x00"
		return table.concat(s)
	end
	if platform.os == "windows" then
		imgui.font.Create {
			{ Font "Segoe UI Emoji" , 18, glyphRanges { 0x23E0, 0x329F, 0x1F000, 0x1FA9F }},
			{ Font "黑体" , 18, glyphRanges { 0x0020, 0xFFFF }},
		}
	elseif platform.os == "macos" then
		imgui.font.Create { { Font "华文细黑" , 18, glyphRanges { 0x0020, 0xFFFF }} }
	elseif platform.os == "ios" then
		imgui.font.Create { { Font "Heiti SC" , 18, glyphRanges { 0x0020, 0xFFFF }} }
	else
		error("unknown os:" .. platform.os)
	end
end

function m:exit()
	imgui.v2.DestroyContext()
end

local KeyboardCode <const> = {
    TAB = "Tab",
    LEFT = "LeftArrow",
    RIGHT = "RightArrow",
    UP = "UpArrow",
    DOWN = "DownArrow",
    PRIOR = "PageUp",
    NEXT = "PageDown",
    HOME = "Home",
    END = "End",
    INSERT = "Insert",
    DELETE = "Delete",
    BACK = "Backspace",
    SPACE = "Space",
    RETURN = "Enter",
    ESCAPE = "Escape",
    OEM_7 = "Apostrophe",
    OEM_COMMA = "Comma",
    OEM_MINUS = "Minus",
    OEM_PERIOD = "Period",
    OEM_2 = "Slash",
    OEM_1 = "Semicolon",
    OEM_PLUS = "Equal",
    OEM_4 = "LeftBracket",
    OEM_5 = "Backslash",
    OEM_6 = "RightBracket",
    OEM_3 = "GraveAccent",
    CAPITAL = "CapsLock",
    SCROLL = "ScrollLock",
    NUMLOCK = "NumLock",
    SNAPSHOT = "PrintScreen",
    PAUSE = "Pause",
    NUMPAD0 = "Keypad0",
    NUMPAD1 = "Keypad1",
    NUMPAD2 = "Keypad2",
    NUMPAD3 = "Keypad3",
    NUMPAD4 = "Keypad4",
    NUMPAD5 = "Keypad5",
    NUMPAD6 = "Keypad6",
    NUMPAD7 = "Keypad7",
    NUMPAD8 = "Keypad8",
    NUMPAD9 = "Keypad9",
    DECIMAL = "KeypadDecimal",
    DIVIDE = "KeypadDivide",
    MULTIPLY = "KeypadMultiply",
    SUBTRACT = "KeypadSubtract",
    ADD = "KeypadAdd",
    LSHIFT = "LeftShift",
    LCONTROL = "LeftCtrl",
    LMENU = "LeftAlt",
    LWIN = "LeftSuper",
    RSHIFT = "RightShift",
    RCONTROL = "RightCtrl",
    RMENU = "RightAlt",
    RWIN = "RightSuper",
    APPS = "Menu",
    ['0'] = "0",
    ['1'] = "1",
    ['2'] = "2",
    ['3'] = "3",
    ['4'] = "4",
    ['5'] = "5",
    ['6'] = "6",
    ['7'] = "7",
    ['8'] = "8",
    ['9'] = "9",
    ['A'] = "A",
    ['B'] = "B",
    ['C'] = "C",
    ['D'] = "D",
    ['E'] = "E",
    ['F'] = "F",
    ['G'] = "G",
    ['H'] = "H",
    ['I'] = "I",
    ['J'] = "J",
    ['K'] = "K",
    ['L'] = "L",
    ['M'] = "M",
    ['N'] = "N",
    ['O'] = "O",
    ['P'] = "P",
    ['Q'] = "Q",
    ['R'] = "R",
    ['S'] = "S",
    ['T'] = "T",
    ['U'] = "U",
    ['V'] = "V",
    ['W'] = "W",
    ['X'] = "X",
    ['Y'] = "Y",
    ['Z'] = "Z",
    F1 = "F1",
    F2 = "F2",
    F3 = "F3",
    F4 = "F4",
    F5 = "F5",
    F6 = "F6",
    F7 = "F7",
    F8 = "F8",
    F9 = "F9",
    F10 = "F10",
    F11 = "F11",
    F12 = "F12",
    F13 = "F13",
    F14 = "F14",
    F15 = "F15",
    F16 = "F16",
    F17 = "F17",
    F18 = "F18",
    F19 = "F19",
    F20 = "F20",
    F21 = "F21",
    F22 = "F22",
    F23 = "F23",
    F24 = "F24",
    BROWSER_BACK = "AppBack",
    BROWSER_FORWARD = "AppForward",
}

local TouchEvent = world:sub { "touch" }
local GesturePinchEvent = world:sub { "gesture", "pinch" }
local KeyboardEvent = world:sub { "keyboard" }
local InputcharEvent = world:sub { "inputchar" }
local FocusEvent = world:sub { "focus" }

function m:start_frame()
	for _, e in TouchEvent:unpack() do
		if e.state == "began" then
			imgui.v2.AddMouseButtonEvent(0, true)
		elseif e.state == "ended" then
			imgui.v2.AddMouseButtonEvent(0, false)
		end
	end
	for _, _, e in GesturePinchEvent:unpack() do
		imgui.v2.AddMouseWheelEvent(e.velocity, e.velocity)
	end
	for _, key, press in KeyboardEvent:unpack() do
		local keyname = KeyboardCode[key]
		if keyname then
			local keycode = imgui.enum.Key[keyname]
			if press == 1 then
				imgui.v2.AddKeyEvent(keycode, true);
			elseif press == 0 then
				imgui.v2.AddKeyEvent(keycode, false);
			end
		end
	end
	for _, e in InputcharEvent:unpack() do
		if e.what == "native" then
			imgui.v2.AddInputCharacter(e.code)
		elseif e.what == "utf16" then
			imgui.v2.AddInputCharacterUTF16(e.code)
		end
	end
	for _, focused in FocusEvent:unpack() do
		imgui.v2.AddFocusEvent(focused)
	end
	imgui.v2.NewFrame()
end

function m:end_frame()
	imgui.Render()
end
