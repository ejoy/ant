local initargs = ...

local ltask		= require "ltask"
local bgfx		= require "bgfx"
local PM		= require "programan.client"
local imgui		= require "imgui"
local assetmgr	= import_package "ant.asset"
local rhwi		= import_package "ant.hwi"
local ecs		= import_package "ant.ecs"
local exclusive	= require "ltask.exclusive"

local message = {}
local initialized = false
local init_width
local init_height
local debug_traceback = debug.traceback
local world

local function mousewheel(x, y, delta)
    local mvp = imgui.GetMainViewport()
    x, y = x - mvp.WorkPos[1], y - mvp.WorkPos[2]
    world:dispatch_message {
        type = "mousewheel",
        x = x,
        y = y,
        delta = delta,
    }
end
local function mouse(x, y, what, state)
    local mvp = imgui.GetMainViewport()
    x, y = x - mvp.MainPos[1], y - mvp.MainPos[2]
    world:dispatch_message {
        type = "mouse",
        x = x,
        y = y,
        what = what,
        state = state,
        timestamp = 0,
    }
end

function message.dropfiles(filelst)
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
    world:dispatch_message {
        type = "size",
        w = init_width,
        h = init_height,
    }
	rhwi.reset(nil, init_width, init_height)
	size_dirty = false
end

local Keyboard = {}
local KeyMods = {}
local Mouse = {}
local MousePosX, MousePosY = 0, 0
local DOWN <const> = {true}

local KeyModifiers <const> = {
	[imgui.enum.Key.LeftCtrl]   = "CTRL",
	[imgui.enum.Key.LeftShift]  = "SHIFT",
	[imgui.enum.Key.LeftAlt]    = "ALT",
	[imgui.enum.Key.LeftSuper]  = "SYS",
	[imgui.enum.Key.RightCtrl]  = "CTRL",
	[imgui.enum.Key.RightShift] = "SHIFT",
	[imgui.enum.Key.RightAlt]   = "ALT",
	[imgui.enum.Key.RightSuper] = "SYS",
}

local function updateIO()
	local MouseChanged = {}
	local KeyboardChanged = {}
	for _, what, x, y in imgui.InputEvents() do
		if what == "MousePos" then
			MousePosX, MousePosY = x, y
			mouse(MousePosX, MousePosY, 4, 2)
		elseif what == "MouseWheel" then
			mousewheel(MousePosX, MousePosY, y)
		elseif what == "MouseButton" then
			local down = DOWN[y]
			local button
			if x == 0 then
				button = "LEFT"
			elseif x == 1 then
				button = "RIGHT"
			else
				button = "MIDDLE"
			end
			local cur = Mouse[button]
			if cur ~= down then
				Mouse[button] = down
				if down then
					mouse(MousePosX, MousePosY, button, "DOWN")
				else
					mouse(MousePosX, MousePosY, button, "UP")
				end
				MouseChanged[button] = true
			end
		elseif what == "Key" then
			local code, down = x, DOWN[y]
			local cur = Keyboard[code]
			if cur ~= down then
				if KeyModifiers[code] then
					if down then
						KeyMods[KeyModifiers[code]] = true
					else
						KeyMods[KeyModifiers[code]] = nil
					end
				end
				Keyboard[code] = down
				if down then
					world:dispatch_message {
						type = "keyboard",
						key = code,
						press = 1,
						state = KeyMods,
					}
				else
					world:dispatch_message {
						type = "keyboard",
						key = code,
						press = 0,
						state = KeyMods,
					}
				end
				KeyboardChanged[code] = true
			end
		end
	end
	for button in pairs(Mouse) do
		if not MouseChanged[button] then
			mouse(MousePosX, MousePosY, button, "MOVE")
		end
	end
	for code in pairs(Keyboard) do
		if not KeyboardChanged[code] then
			world:dispatch_message {
				type = "keyboard",
				key = code,
				press = 2,
				state = KeyMods,
			}
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

ltask.fork(function ()
	import_package "ant.hwi".init_bgfx()
    init_width, init_height = initargs.w, initargs.h

	imgui.CreateContext()
	imgui.io.ConfigFlags = imgui.flags.Config {
		"NavEnableKeyboard",
		"ViewportsEnable",
		"DockingEnable",
		"NavNoCaptureKeyboard",
		"DpiEnableScaleViewports",
		"DpiEnableScaleFonts",
	}
	imgui.SetCallback(dispatch)
	local nwh = imgui.CreateMainWindow(initargs.w, initargs.h)
	rhwi.init {
		nwh = nwh,
		scene = {
			viewrect = {x = 0, y = 0, w = 1920, h = 1080},
			resolution = {w = 1920, h = 1080},
			scene_ratio = 1,
			ui_ratio = 1,
		}
    }
    bgfx.encoder_create "imgui"
    bgfx.encoder_init()
	assetmgr.init()
    bgfx.encoder_begin()

	local imgui_font = assetmgr.load_material "/pkg/ant.imgui/materials/font.material"
	local imgui_image = assetmgr.load_material "/pkg/ant.imgui/materials/image.material"
	assetmgr.material_mark(imgui_font.fx.prog)
	assetmgr.material_mark(imgui_image.fx.prog)
	imgui.InitPlatform(nwh)
	imgui.InitRender(
		PM.program_get(imgui_font.fx.prog),
		PM.program_get(imgui_image.fx.prog),
		imgui_font.fx.uniforms.s_tex.handle,
		imgui_image.fx.uniforms.s_tex.handle
	)

    world = ecs.new_world {
        name = "editor",
        scene = {
            viewrect = {x = 0, y = 0, w = 1920, h = 1080},
            resolution = {w = 1920, h = 1080},
            scene_ratio = 1,
        },
     	device_size = {x=0, y=0, w=1920, h=1080},
        ecs = initargs.ecs,
    }
    world:pipeline_init()
    initialized = true
    while imgui.DispatchMessage() do
		imgui.NewFrame()
        updateIO()
		update_size()
        world:pipeline_update()
        imgui.Render()
        bgfx.encoder_end()
        rhwi.frame()
        exclusive.sleep(1)
        bgfx.encoder_begin()
        ltask.sleep(0)
    end
	world:pipeline_exit()
	imgui.DestroyRenderer()
	imgui.DestroyPlatform()
	imgui.DestroyContext()
	imgui.DestroyMainWindow()
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
function S.msg()
end

return S
