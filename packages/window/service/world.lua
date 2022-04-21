local initargs = ...

local ltask     = require "ltask"
local inputmgr  = import_package "ant.inputmgr"
local ecs       = import_package "ant.ecs"
local rhwi      = import_package "ant.hwi"
local cr        = import_package "ant.compile_resource"
local setting	= import_package "ant.settings".setting
local mu		= import_package "ant.math".util

local bgfx      = require "bgfx"
local ServiceBgfxMain = ltask.queryservice "ant.render|bgfx_main"
for _, name in ipairs(ltask.call(ServiceBgfxMain, "APIS")) do
	bgfx[name] = function (...)
		return ltask.call(ServiceBgfxMain, name, ...)
	end
end

local ServiceWindow = ltask.queryservice "ant.window|window"
ltask.send(ServiceWindow, "subscribe", {
	"init",
	"exit",
	"mouse_wheel",
	"mouse",
	"touch",
	"keyboard",
	"char",
	"size",
	"gesture"
})
local resizeQueue = {}

local S = {}

local config = {
	ecs = initargs
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

local function render()
	while true do
		check_size()
		world:pipeline_update()
		bgfx.encoder_end()
		encoderBegin = false
		do
			rhwi.frame()
		end
		world:pipeline_update_end()
		if quit then
			ltask.wakeup(quit)
			return
		end
		bgfx.encoder_begin()
		encoderBegin = true
		ltask.sleep(0)
	end
end

local function calc_fb_size(w, h, ratio)
	return mu.cvt_size(w, ratio), mu.cvt_size(h, ratio)
end

function S.init(nwh, context, width, height)
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
	bgfx.encoder_create()
	bgfx.encoder_init()
	import_package "ant.render".init_bgfx()
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
	S.size			= function (ww, hh)
		init_width, init_height = calc_fb_size(ww, hh, world.args.framebuffer.ratio)
	end
	do_size			= ev.size
	world:pipeline_init()

	for _, size in ipairs(resizeQueue) do
		S.size(size[1], size[2])
	end

	ltask.fork(render)
end

S.mouse_wheel = function () end
S.mouse = function () end
S.touch = function () end
S.gesture = function () end
S.keyboard = function () end
S.char = function () end
S.size = function (w,h)
	resizeQueue[#resizeQueue+1] = {w,h}
end
function S.exit()
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
	ltask.send(ServiceWindow, "unsubscribe_all")
	rhwi.shutdown()
    print "exit"
end

S.message = function(...)
	world:pub {"task-message", ...}
end

return S
