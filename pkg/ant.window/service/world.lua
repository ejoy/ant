local initargs = ...

local ltask     = require "ltask"
local inputmgr  = import_package "ant.inputmgr"
local ecs       = import_package "ant.ecs"
local rhwi      = import_package "ant.hwi"
local audio     = import_package "ant.audio"
local bgfx      = require "bgfx"

local ServiceRmlUi
ltask.fork(function ()
    ServiceRmlUi = ltask.uniqueservice("ant.rmlui|rmlui", ltask.self())
end)

local S = ltask.dispatch {}


local function dummy_time() end
local world
local event = { time = dummy_time }
local encoderBegin = false
local quit
local will_reboot

local function reboot(initargs)
	local config = world.args
	config.REBOOT = true
	config.ecs = initargs
	world:pipeline_exit()
	world = ecs.new_world(config)
	local ev 		= inputmgr.create(world, "win32")
	event.keyboard		= ev.keyboard
	event.mouse 		= ev.mouse
	event.mousewheel	= ev.mousewheel
	event.touch			= ev.touch
	event.gesture		= ev.gesture
	event.size			= ev.size
	event.time			= ev.time or dummy_time
	world:pipeline_init()
end

local function render(nwh, context, width, height, initialized)
	local config = {
		ecs = initargs,
	}
	config.framebuffer = {
		width = width,
		height = height,
	}
	config.viewport = {
		x=0, y=0, w=width, h=height
	}
	rhwi.init {
		nwh			= nwh,
		context		= context,
		framebuffer = config.framebuffer,
	}
	rhwi.set_profie(true)
	bgfx.encoder_create "world"
	bgfx.encoder_init()
	import_package "ant.asset".init()
	bgfx.encoder_begin()
	encoderBegin = true
	world = ecs.new_world(config)

	local ev 		= inputmgr.create(world, "win32")

	event.keyboard		= ev.keyboard
	event.mouse 		= ev.mouse
	event.mousewheel	= ev.mousewheel
	event.touch			= ev.touch
	event.gesture		= ev.gesture
	event.size			= ev.size
	event.time			= ev.time or dummy_time

	event.size(width, height)
	audio.init()
	world:pipeline_init()

	ltask.wakeup(initialized)
	initialized = nil

	while true do
		if will_reboot then
			reboot(will_reboot)
			will_reboot = nil
		end
		world:pipeline_update()
		bgfx.encoder_end()
		encoderBegin = false
		do
			audio.frame()
			rhwi.frame()
		end
		if quit then
			ltask.wakeup(quit)
			return
		end
		bgfx.encoder_begin()
		encoderBegin = true
		ltask.sleep(0)
	end
end

function event.init(nwh, context, width, height)
	import_package "ant.hwi".init_bgfx()
	local initialized = {}
	ltask.fork(render, nwh, context, width, height, initialized)
	ltask.wait(initialized)
end

function event.recreate(nwh, _, width, height)
	bgfx.set_platform_data {
		nwh = nwh
	}
	event.size(width, height)
end

function event.suspend(what)
	bgfx.event_suspend(what)
end

local ms_queue = {}
local ms_quit
local ms_token = {}

local function table_append(t, a)
	table.move(a, 1, #a, #t+1, t)
end

local function dispatch(timestamp, cmd, ...)
	local f = assert(event[cmd], cmd)
	event.time(timestamp)
	f(...)
end

ltask.fork(function ()
	while not ms_quit do
		while true do
			local m = table.remove(ms_queue, 1)
			if not m then
				break
			end
			dispatch(m.t, table.unpack(m, 1, m.n))
		end
		ltask.wait(ms_token)
	end
end)

function S.msg(messages)
	if #ms_queue == 0 then
		table_append(ms_queue, messages)
		ltask.wakeup(ms_token)
	else
		table_append(ms_queue, messages)
	end
end

function event.exit()
	ms_quit = true
	quit = {}
	ltask.wait(quit)
	if ServiceRmlUi then
		ltask.send(ServiceRmlUi, "shutdown")
		ServiceRmlUi = nil
	end
	if world then
		world:pipeline_exit()
        world = nil
	end
	if encoderBegin then
		bgfx.encoder_end()
	end
	bgfx.encoder_destroy()
	rhwi.shutdown()
    print "exit"
    ltask.multi_wakeup "quit"
end

function S.reboot(initargs)
	will_reboot = initargs
end

function S.wait()
    ltask.multi_wait "quit"
end
