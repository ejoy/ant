local packagename, w, h = ...

local ltask     = require "ltask"
local bgfx      = require "bgfx"
local ServiceBgfxMain = ltask.queryservice "ant.render|bgfx_main"
for _, name in ipairs(ltask.call(ServiceBgfxMain, "APIS")) do
	bgfx[name] = function (...)
		return ltask.call(ServiceBgfxMain, name, ...)
	end
end

local imgui       = require "imgui"
local renderpkg   = import_package "ant.render"
local viewidmgr   = renderpkg.viewidmgr
local assetmgr    = import_package "ant.asset"
local rhwi        = import_package "ant.hwi"
local platform    = require "platform"
local exclusive   = require "ltask.exclusive"
local font        = imgui.font
local Font        = platform.font
local cb          = {}
local message     = {}
local initialized = false
local init_width
local init_height
local debug_traceback = debug.traceback
local viewids = {}

local _timer = require "platform.timer"
local _time_counter = _timer.counter
local _time_freq    = _timer.frequency() / 1000
local _timer_previous = _time_counter() / _time_freq
local function timer_delta()
	local current = _time_counter() / _time_freq
	local delta = current - _timer_previous
	_timer_previous = current
	return delta
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
	[imgui.enum.Key.ModCtrl]  = 0,
	[imgui.enum.Key.ModShift] = 1,
	[imgui.enum.Key.ModAlt]   = 2,
	[imgui.enum.Key.ModSuper] = 4,
}

local function updateIO()
	local MouseChanged = {}
	local KeyboardChanged = {}
	for _, what,x, y in imgui.InputEvents() do
		if what == "MousePos" then
			MousePosX, MousePosY = x, y
			cb.mouse(MousePosX, MousePosY)
		elseif what == "MouseWheel" then
			cb.mouse_wheel(MousePosX, MousePosY, y)
		elseif what == "MouseButton" then
			local button, down = x, DOWN[y]
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
					cb.keyboard(code, 1, KeyMods)
				else
					cb.keyboard(code, 0, KeyMods)
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


local tokenmap = {}
local function multi_wait(key)
	local mtoken = tokenmap[key]
	if not mtoken then
		mtoken = {}
		tokenmap[key] = mtoken
	end
	local t = {}
	mtoken[#mtoken+1] = t
	return ltask.wait(t)
end

local function multi_wakeup(key, ...)
	local mtoken = tokenmap[key]
	if mtoken then
		tokenmap[key] = nil
		for _, token in ipairs(mtoken) do
			ltask.wakeup(token, ...)
		end
	end
end

local config = pm.loadcfg(packagename)
ltask.fork(function ()
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
    bgfx.encoder_create()
    bgfx.encoder_init()
	renderpkg.init_bgfx()
    bgfx.encoder_begin()

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
    multi_wakeup "quit"
    print "exit"
end)

local S = {}

function S.wait()
    multi_wait "quit"
end

--TODO
function S.mouse()
end
function S.touch()
end

return S
