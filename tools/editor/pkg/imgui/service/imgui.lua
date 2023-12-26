local initargs = ...

local ltask		= require "ltask"
local bgfx		= require "bgfx"
local assetmgr	= import_package "ant.asset"
local rhwi		= import_package "ant.hwi"
local ecs		= import_package "ant.ecs"
local exclusive	= require "ltask.exclusive"
local window	= require "window"
local inputmgr	= import_package "ant.inputmgr"

local initialized = false
local init_width
local init_height
local world

local size_dirty

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

local WindowMessage = {}
local WindowQueue = {}
local WindowEvent = {}
local WindowQuit
local WindowToken = {}

function WindowEvent.exit()
	WindowQuit = true
end

function WindowEvent.size(e)
	if initialized then
		size_dirty = true
	end
	init_width = e.w
	init_height = e.h
	world:dispatch_message(e)
end

ltask.fork(function ()
	while not WindowQuit do
		while true do
			local m = table.remove(WindowQueue, 1)
			if not m then
				break
			end
			local f = WindowEvent[m.type]
			if f then
				f(m)
			else
				world:dispatch_message(m)
			end
		end
		ltask.wait(WindowToken)
	end
end)

local function WindowDispatch()
	if #WindowMessage == 0 then
		return
	end
	local wakeup = #WindowQueue == 0
	inputmgr:filter_imgui(WindowMessage, WindowQueue)
	if wakeup then
		ltask.wakeup(WindowToken)
	end
end

ltask.fork(function ()
	import_package "ant.hwi".init_bgfx()
    init_width, init_height = initargs.w, initargs.h

	local nwh = window.init(WindowMessage, ("%dx%d"):format(initargs.w, initargs.h))
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
	inputmgr:enable_imgui()
    while window.peekmessage() do
		WindowDispatch()
		update_size()
		world:dispatch_message { type = "update" }
        world:pipeline_update()
        bgfx.encoder_end()
        rhwi.frame()
        exclusive.sleep(1)
        bgfx.encoder_begin()
        ltask.sleep(0)
    end
	world:pipeline_exit()
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
