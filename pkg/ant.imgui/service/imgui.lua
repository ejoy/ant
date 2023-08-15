local initargs = ...

local ltask		= require "ltask"
local bgfx		= require "bgfx"
local PM		= require "programan.client"
local imgui		= require "imgui"
local assetmgr	= import_package "ant.asset"
local rhwi		= import_package "ant.hwi"
local exclusive	= require "ltask.exclusive"

local cb          	= {}
local message     	= {}
local initialized 	= false
local init_width
local init_height
local debug_traceback = debug.traceback

local _, _timer_previous = ltask.now()
local function timer_delta()
	local _, current = ltask.now()
	local delta = current - _timer_previous
	_timer_previous = current
	return delta * 10
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

local viewidcount = 0
local imgui_viewids = {}

for i=1, 16 do
	imgui_viewids[i] = rhwi.viewid_generate("imgui_eidtor" .. i, "uiruntime")
end

function message.viewid()
	if viewidcount >= #imgui_viewids then
		error(("imgui viewid range exceeded, max count:%d"):format(#imgui_viewids))
	end

	viewidcount = viewidcount + 1
	return imgui_viewids[viewidcount]
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
			cb.mousewheel(MousePosX, MousePosY, y)
		elseif what == "MouseButton" then
			local down = DOWN[y]
			local button = x
			if x == 0 then
				button = 1
			elseif x == 1 then
				button = 3
			end
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

local callback = import_package(initargs.packagename)
for _, name in ipairs {"init","update","exit","size","mousewheel","mouse","keyboard"} do
	cb[name] = callback[name] or (function () end)
end

ltask.fork(function ()
	import_package "ant.hwi".init_bgfx()
    init_width, init_height = initargs.w, initargs.h

    local nwh = imgui.Create(dispatch, initargs.w, initargs.h)
    rhwi.init {
        nwh = nwh,
		framebuffer = {
			width = init_width,
			height = init_height,
			scene_ratio = 1,
			ui_ratio = 1,
		}
    }
    bgfx.encoder_create "imgui"
    bgfx.encoder_init()
	assetmgr.init()
    bgfx.encoder_begin()

    local imgui_font = assetmgr.load_material "/pkg/ant.imgui/materials/font.material"
	assetmgr.material_mark(imgui_font.fx.prog)
    imgui.SetFontProgram(
        PM.program_get(imgui_font.fx.prog),
        imgui_font.fx.uniforms[1].handle
    )
    local imgui_image = assetmgr.load_material "/pkg/ant.imgui/materials/image.material"
	assetmgr.material_mark(imgui_image.fx.prog)
    imgui.SetImageProgram(
        PM.program_get(imgui_image.fx.prog),
        imgui_image.fx.uniforms[1].handle
    )

	cb.init(init_width, init_height, initargs)
    initialized = true
    while imgui.NewFrame() do
        updateIO()
		update_size()
        cb.update(uieditor_viewid, timer_delta())
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
