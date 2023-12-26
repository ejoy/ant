local initargs = ...

local ltask     = require "ltask"
local ecs       = import_package "ant.ecs"
local rhwi      = import_package "ant.hwi"
local audio     = import_package "ant.audio"
local setting   = import_package "ant.settings"
local inputmgr  = import_package "ant.inputmgr"
local bgfx      = require "bgfx"
local mu		= import_package "ant.math".util
local ServiceRmlUi
ltask.fork(function ()
    ServiceRmlUi = ltask.uniqueservice("ant.rmlui|rmlui", ltask.self())
end)

local S = ltask.dispatch {}

local world
local event = {}
local encoderBegin = false
local quit
local will_reboot


local function reboot(initargs)
	local config = world.args
	local enable_mouse = config.ecs.enable_mouse
	config.REBOOT = true
	config.ecs = initargs
	config.ecs.enable_mouse = enable_mouse
	world:pipeline_exit()
	world = ecs.new_world(config)
	world:pipeline_init()
end

local SCENE_RATIO <const> = setting:get "scene/scene_ratio" or 1.0
local RESOLUTION_WIDTH, RESOLUTION_HEIGHT <const> = 1280, 720

local function render(nwh, context, width, height, initialized)

	local function get_resolution()
		local w, h
		w, h = (setting:get "scene/resolution"):match "(%d+)%a(%d+)"
		return {w = tonumber(w and w or RESOLUTION_WIDTH), h = tonumber(h and h or RESOLUTION_HEIGHT)}
	end

	local config = {
		ecs = initargs,
	}

	local resolution = get_resolution()

	config.device_size = {
		x = 0,
		y = 0,
		w = width,
		h = height
	}

	local vp = config.device_size
	local vr = mu.get_scene_view_rect(resolution.w, resolution.h, vp, SCENE_RATIO)

	config.scene = {
		viewrect = vr,
		resolution = resolution,
		scene_ratio = SCENE_RATIO,
	}

	log.info("scene viewrect: ", vr.x, vr.y, vr.w, vr.h)
	log.info("scene ratio: ", SCENE_RATIO)
	log.info("device viewport: ", vp.x, vp.y, vp.w, vp.h)
	rhwi.init {
		nwh			= nwh,
		context		= context,
		scene       = config.scene,
	}
	rhwi.set_profie(false)
	bgfx.encoder_create "world"
	bgfx.encoder_init()
	import_package "ant.asset".init()
	bgfx.encoder_begin()
	encoderBegin = true
	world = ecs.new_world(config)
	world:dispatch_message {
		type = "set_viewport",
		viewport = config.device_size,
	}

	world:pipeline_init()

	ltask.wakeup(initialized)
	initialized = nil

	while true do
		if will_reboot then
			reboot(will_reboot)
			will_reboot = nil
		end
		world:dispatch_message { type = "update" }
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

function event.init(m)
	import_package "ant.hwi".init_bgfx()
	local initialized = {}
	ltask.fork(render, m.nwh, m.context, m.w, m.h, initialized)
	ltask.wait(initialized)
end

function event.recreate(m)
	bgfx.set_platform_data {
		nwh = m.nwh
	}
	world:dispatch_message {
		type = "size",
		w = m.w,
		h = m.h,
	}
end

function event.suspend(m)
	bgfx.event_suspend(m.what)
end

local ms_queue = {}
local ms_quit
local ms_token = {}

ltask.fork(function ()
	while not ms_quit do
		while true do
			local m = table.remove(ms_queue, 1)
			if not m then
				break
			end
			local f = event[m.type]
			if f then
				f(m)
			else
				world:dispatch_message(m)
			end
		end
		ltask.wait(ms_token)
	end
end)

function S.msg(messages)
	if #ms_queue == 0 then
		inputmgr:filter_imgui(messages, ms_queue)
		ltask.wakeup(ms_token)
	else
		inputmgr:filter_imgui(messages, ms_queue)
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
