local initargs = ...

if not __ANT_RUNTIME__ then
	if package.loaded.math3d then
		error "need init math3d MAXPAGE"
	end
	debug.getregistry().MATH3D_MAXPAGE = 10240
end

local ltask     = require "ltask"
local inputmgr  = import_package "ant.inputmgr"
local ecs       = import_package "ant.ecs"
local rhwi      = import_package "ant.hwi"
local cr        = import_package "ant.compile_resource"
local audio     = import_package "ant.audio"
local setting	= import_package "ant.settings".setting
local mu		= import_package "ant.math".util
local platform  = require "bee.platform"
local bgfx      = require "bgfx"

local S = ltask.dispatch {}

local config = {
	ecs = initargs,
	DEBUG = platform.DEBUG or platform.os ~= "ios"
}

local world
local encoderBegin = false
local quit

local init_width, init_height
local do_size

local function calc_viewport(fbw, fbh)
	return {
		x=0, y=0, w=fbw, h=fbh
	}
end

local function update_config(args, ww, hh)
	local fb = args.framebuffer
	fb.width, fb.height = ww, hh

	local vp = args.viewport
	if vp == nil then
		vp = {}
		args.viewport = vp
	end
	vp.x, vp.y, vp.w, vp.h = 0, 0, ww, hh
	if world then
		world:pub{"world_viewport_changed", vp}
	end
end

local function check_size()
	local fb = world.args.framebuffer
	if init_width ~= fb.width or init_height ~= fb.height then
		update_config(world.args, init_width, init_height)
		do_size(init_width, init_height)
		rhwi.reset(nil, init_width, init_height)
	end
end

local function calc_fb_size(w, h, ratio)
	return mu.cvt_size(w, ratio), mu.cvt_size(h, ratio)
end

local function resize(ww, hh)
	init_width, init_height = calc_fb_size(ww, hh, world.args.framebuffer.ratio)
end

local function render(nwh, context, width, height, initialized)
	local scene_ratio = setting:get "graphic/framebuffer/scene_ratio" or 1.0
	local ratio = setting:get "graphic/framebuffer/ratio" or 1.0
	log.info(("framebuffer ratio:%2f, scene:%2f"):format(ratio, scene_ratio))

	init_width, init_height = calc_fb_size(width, height, ratio)

	log.info("framebuffer size:", init_width, init_height)

	local framebuffer = {
		width	= init_width,
		height	= init_height,
		ratio 	= ratio,
		scene_ratio = scene_ratio,
	}
	rhwi.init {
		nwh		= nwh,
		context	= context,
		framebuffer = framebuffer,
	}
	cr.init()
	bgfx.set_debug "T"
	bgfx.encoder_create "world"
	bgfx.encoder_init()
	import_package "ant.asset".init()
	bgfx.encoder_begin()
	encoderBegin = true
	config.framebuffer = framebuffer
	update_config(config, init_width, init_height)
	world = ecs.new_world(config)
	log.info("main viewport:", world.args.viewport.x, world.args.viewport.y, world.args.viewport.w, world.args.viewport.h)
	world:pub{"world_viewport_changed", world.args.viewport}
	local ev 		= inputmgr.create(world, "win32")

	S.mouse_wheel	= ev.mouse_wheel
	S.mouse 		= ev.mouse
	S.touch			= ev.touch
	S.gesture		= ev.gesture
	S.keyboard		= ev.keyboard
	S.char			= ev.char
	S.size			= resize
	do_size			= ev.size
	world:pipeline_init()

	ltask.wakeup(initialized)
	initialized = nil

	while true do
		check_size()
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

function S.init(nwh, context, width, height)
	import_package "ant.render".init_bgfx()
	local initialized = {}
	ltask.fork(render, nwh, context, width, height, initialized)
	ltask.wait(initialized)
end

function S.recreate(nwh, _, width, height)
	bgfx.set_platform_data {
		nwh = nwh
	}
	S.size(width, height)
end

local ms_queue
local ms_quit
local ms_token = {}

local function table_append(t, a)
	table.move(a, 1, #a, #t+1, t)
end

local function dispatch(cmd, ...)
	local f = assert(S[cmd], cmd)
	f(...)
end

local function dispatch_all()
	local mq = ms_queue
	ms_queue = nil
	for i = 1, #mq do
		local m = mq[i]
		dispatch(table.unpack(m, 1, m.n))
	end
end

ltask.fork(function ()
	while not ms_quit do
		if ms_queue == nil then
			ltask.wait(ms_token)
		end
		dispatch_all()
	end
end)

function S.msg(messages)
	if ms_queue == nil then
		ms_queue = messages
		ltask.wakeup(ms_token)
	else
		table_append(ms_queue, messages)
	end
end

function S.exit()
	ms_quit = true
	quit = {}
	ltask.wait(quit)
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

function S.wait()
    ltask.multi_wait "quit"
end
