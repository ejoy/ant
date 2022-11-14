local packagename, w, h = ...

local ltask     = require "ltask"
local bgfx      = require "bgfx"

local imgui       = require "imgui"
local renderpkg   = import_package "ant.render"
local viewidmgr   = renderpkg.viewidmgr
local assetmgr    = import_package "ant.asset"
local rhwi        = import_package "ant.hwi"
local platform    = require "bee.platform"
local exclusive   = require "ltask.exclusive"
local font        = imgui.font
local Font        = require "platform".font
local fs 		  = require "filesystem"
local cb          = {}
local message     = {}
local initialized = false
local init_width
local init_height
local debug_traceback = debug.traceback
local viewids = {}

local _, _timer_previous = ltask.now()
local function timer_delta()
	local _, current = ltask.now()
	local delta = current - _timer_previous
	_timer_previous = current
	return delta * 10
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

function message.dropfiles(filelst)
	cb.dropfiles(filelst)
end

local size_dirty
function message.size(width,height)
	if initialized then
		size_dirty = true
	end
	init_width = width
	init_height = height
end

local uieditor_viewid<const>, imgui_max_viewid_count<const> = viewidmgr.get_range "uieditor"

function message.viewid()
	local viewid = uieditor_viewid+#viewids
	if viewid >= uieditor_viewid + imgui_max_viewid_count then
		error(("imgui viewid range exceeded, max count:%d"):format(imgui_max_viewid_count))
	end
	viewids[#viewids+1] = viewid
	return viewid
end

local function update_size()
	if not size_dirty then return end
	cb.size(init_width, init_height)
	rhwi.reset(nil, init_width, init_height)
	size_dirty = false
end

local Keyboard = {}
local KeyMods = 0
local Mouse = {}
local MousePosX, MousePosY = 0, 0
local DOWN <const> = {true}

local KeyModifiers = {
	[imgui.enum.Key.LeftCtrl]   = 0x00,
	[imgui.enum.Key.LeftShift]  = 0x01,
	[imgui.enum.Key.LeftAlt]    = 0x02,
	[imgui.enum.Key.LeftSuper]  = 0x04,
	[imgui.enum.Key.RightCtrl]  = 0x00,
	[imgui.enum.Key.RightShift] = 0x10,
	[imgui.enum.Key.RightAlt]   = 0x20,
	[imgui.enum.Key.RightSuper] = 0x40,
}

local function updateIO()
	local MouseChanged = {}
	local KeyboardChanged = {}
	for _, what,x, y in imgui.InputEvents() do
		if what == "MousePos" then
			MousePosX, MousePosY = x, y
			cb.mouse(MousePosX, MousePosY, 4, 2)
		elseif what == "MouseWheel" then
			cb.mouse_wheel(MousePosX, MousePosY, y)
		elseif what == "MouseButton" then
			local button, down = x + 1, DOWN[y]
			local cur = Mouse[button]
			if cur ~= down then
				Mouse[button] = down
				if down then
					cb.mouse(MousePosX, MousePosY, button, 1)
				else
					cb.mouse(MousePosX, MousePosY, button, 3)
				end
				MouseChanged[button] = true
			end
		elseif what == "Key" then
			local code, down = x, DOWN[y]
			local cur = Keyboard[code]
			if cur ~= down then
				if KeyModifiers[code] then
					if down then
						KeyMods = KeyMods | (1<<KeyModifiers[code])
					else
						KeyMods = KeyMods & (~(1<<KeyModifiers[code]))
					end
				end
				Keyboard[code] = down
				if down then
					cb.keyboard(code, 1, ((KeyMods & 0x0F) | (KeyMods >> 8)))
				else
					cb.keyboard(code, 0, ((KeyMods & 0x0F) | (KeyMods >> 8)))
				end
				KeyboardChanged[code] = true
			end
		end
	end
	for button in pairs(Mouse) do
		if not MouseChanged[button] then
			cb.mouse(MousePosX, MousePosY, button, 2)
		end
	end
	for code in pairs(Keyboard) do
		if not KeyboardChanged[code] then
			cb.keyboard(code, 2, KeyMods)
		end
	end
end

local dispatch = {}
for n, f in pairs(message) do
	dispatch[n] = function (...)
		local ok, err = xpcall(f, debug_traceback, ...)
		if ok then
			return err
		else
			print(err)
		end
	end
end

local ServiceWindow = ltask.uniqueservice "ant.window|window"
local pm = require "packagemanager"
local callback = pm.import(packagename)
for _, name in ipairs {"init","update","exit","size","mouse_wheel","mouse","keyboard"} do
    local f = callback[name]
    cb[name] = function (...)
		if f then f(...) end
		ltask.send(ServiceWindow, "send_"..name, ...)
	end
end

local config = pm.loadcfg(packagename)
ltask.fork(function ()
	renderpkg.init_bgfx()
    init_width, init_height = w, h

    local nwh = imgui.Create(dispatch, w, h)
    rhwi.init {
        nwh = nwh,
		framebuffer = {
			width = init_width,
			height = init_height,
			scene_ratio = 1,
			ui_ratio = 1,
		}
    }
	import_package "ant.compile_resource".init()
    bgfx.encoder_create "imgui"
    bgfx.encoder_init()
	assetmgr.init()
    bgfx.encoder_begin()

    local imgui_font = assetmgr.load_fx "/pkg/ant.imgui/materials/font.material"
    imgui.SetFontProgram(
        imgui_font.fx.prog,
        imgui_font.fx.uniforms[1].handle
    )
    local imgui_image = assetmgr.load_fx "/pkg/ant.imgui/materials/image.material"
    imgui.SetImageProgram(
        imgui_image.fx.prog,
        imgui_image.fx.uniforms[1].handle
    )

	if platform.os == "windows" then
		local ff = assert(fs.open(fs.path("/pkg/tools.prefab_editor/res/fonts/fa-solid-900.ttf"), "rb"))
		local fafontdata = ff:read "a"
		ff:close()
        font.Create {
            { Font "Segoe UI Emoji" , 18, glyphRanges { 0x23E0, 0x329F, 0x1F000, 0x1FA9F }},
            { Font "黑体" , 18, glyphRanges { 0x0020, 0xFFFF }},
			{ fafontdata, 16, glyphRanges {
				0xf062, -- ICON_FA_ARROW_UP 			"\xef\x81\xa2"	U+f062
				0xf063,	-- ICON_FA_ARROW_DOWN 			"\xef\x81\xa3"	U+f063
				0xf0c7,	-- ICON_FA_FLOPPY_DISK 			"\xef\x83\x87"	U+f0c7
				0xf04b, -- ICON_FA_PLAY 				"\xef\x81\x8b"	U+f04b
				0xf04d, -- ICON_FA_STOP 				"\xef\x81\x8d"	U+f04d
				0xf14a, -- ICON_FA_SQUARE_CHECK 		"\xef\x85\x8a"	U+f14a
				0xf2d3, -- ICON_FA_SQUARE_XMARK 		"\xef\x8b\x93"	U+f2d3
				0xf05e, -- ICON_FA_BAN 					"\xef\x81\x9e"	U+f05e
				0xf1f8, -- ICON_FA_TRASH 				"\xef\x87\xb8"	U+f1f8
				0xf2ed, -- ICON_FA_TRASH_CAN 			"\xef\x8b\xad"	U+f2ed
				0xf28b, -- ICON_FA_CIRCLE_PAUSE 		"\xef\x8a\x8b"	U+f28b
				0xf144, -- ICON_FA_CIRCLE_PLAY 			"\xef\x85\x84"	U+f144
				0xf28d, -- ICON_FA_CIRCLE_STOP 			"\xef\x8a\x8d"	U+f28d
				0xf0fe, -- ICON_FA_SQUARE_PLUS 			"\xef\x83\xbe"	U+f0fe
				0xf0e2, -- ICON_FA_ARROW_ROTATE_LEFT 	"\xef\x83\xa2"	U+f0e2
				0xf01e, -- ICON_FA_ARROW_ROTATE_RIGHT 	"\xef\x80\x9e"	U+f01e
				0xf002, -- ICON_FA_MAGNIFYING_GLASS 	"\xef\x80\x82"	U+f002
				0xf07b, -- ICON_FA_FOLDER 				"\xef\x81\xbb"	U+f07b
				0xf07c, -- ICON_FA_FOLDER_OPEN 			"\xef\x81\xbc"	U+f07c
				0xe4c2, -- ICON_FA_ARROWS_UP_TO_LINE 	"\xee\x93\x82"	U+e4c2
				0xe4b8, -- ICON_FA_ARROWS_DOWN_TO_LINE  "\xee\x92\xb8"	U+e4b8
				0xf65e, -- ICON_FA_FOLDER_PLUS 			"\xef\x99\x9e"	U+f65e
				0xf65d, -- ICON_FA_FOLDER_MINUS 		"\xef\x99\x9d"	U+f65d
				0xf24d, -- ICON_FA_CLONE 				"\xef\x89\x8d"	U+f24d
				0xf068, -- ICON_FA_MINUS 				"\xef\x81\xa8"	U+f068
				0xf019, -- ICON_FA_DOWNLOAD 			"\xef\x80\x99"	U+f019
				0xf00d, -- ICON_FA_XMARK 				"\xef\x80\x8d"	U+f00d
				0xf013, -- ICON_FA_GEAR 				"\xef\x80\x93"	U+f013
				0xf085, -- ICON_FA_GEARS 				"\xef\x82\x85"	U+f085
				0xf15b, -- ICON_FA_FILE 				"\xef\x85\x9b"	U+f15b
				0xf31c, -- ICON_FA_FILE_PEN 			"\xef\x8c\x9c"	U+f31c
				0xf304, -- ICON_FA_PEN 					"\xef\x8c\x84"	U+f304
				0xf0eb, -- ICON_FA_LIGHTBULB 			"\xef\x83\xab"	U+f0eb
				0xf03a, -- ICON_FA_LIST 				"\xef\x80\xba"	U+f03a
				0xf023, -- ICON_FA_LOCK 				"\xef\x80\xa3"	U+f023
				0xf3c1, -- ICON_FA_LOCK_OPEN 			"\xef\x8f\x81"	U+f3c1
				0xf06e, -- ICON_FA_EYE 					"\xef\x81\xae"	U+f06e
				0xf070, -- ICON_FA_EYE_SLASH 			"\xef\x81\xb0"	U+f070
				0xf00c, -- ICON_FA_CHECK 				"\xef\x80\x8c"	U+f00c
				0xf058, -- ICON_FA_CIRCLE_CHECK 		"\xef\x81\x98"	U+f058
				0xf056, -- ICON_FA_CIRCLE_MINUS 		"\xef\x81\x96"	U+f056
				0xf055, -- ICON_FA_CIRCLE_PLUS 			"\xef\x81\x95"	U+f055
				0xf120, -- ICON_FA_TERMINAL 			"\xef\x84\xa0"	U+f120
				0xf05a, -- ICON_FA_CIRCLE_INFO 			"\xef\x81\x9a"	U+f05a
				0xf35d, -- ICON_FA_UP_RIGHT_FROM_SQUARE "\xef\x8d\x9d"	U+f35d
				0xf071, -- ICON_FA_TRIANGLE_EXCLAMATION "\xef\x81\xb1"	U+f071
			}},
        }
    elseif platform.os == "macos" then
        font.Create { { Font "华文细黑" , 18, glyphRanges { 0x0020, 0xFFFF }} }
    else -- iOS
        font.Create { { Font "Heiti SC" , 18, glyphRanges { 0x0020, 0xFFFF }} }
    end
	cb.init(init_width, init_height, config)
    initialized = true
    while imgui.NewFrame() do
        updateIO()
		update_size()
        cb.update(viewids[1], timer_delta())
        imgui.Render()
        bgfx.encoder_end()
        rhwi.frame()
        exclusive.sleep(1)
        bgfx.encoder_begin()
        ltask.sleep(0)
    end
    cb.exit()
    imgui.Destroy()
    bgfx.encoder_end()
	bgfx.encoder_destroy()
    rhwi.shutdown()
    ltask.multi_wakeup "quit"
    print "exit"
end)

local S = {}

function S.wait()
    ltask.multi_wait "quit"
end

--TODO
function S.mouse()
end
function S.touch()
end

return S
