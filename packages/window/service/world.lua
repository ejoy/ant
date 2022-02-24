local initargs = ...

local ltask     = require "ltask"
local inputmgr  = import_package "ant.inputmgr"
local ecs       = import_package "ant.ecs"
local rhwi      = import_package "ant.hwi"
local cr        = import_package "ant.compile_resource"
local setting	= import_package "ant.settings".setting

local bgfx      = require "bgfx"
local ServiceBgfxMain = ltask.queryservice "ant.render|bgfx_main"
for _, name in ipairs(ltask.call(ServiceBgfxMain, "APIS")) do
	bgfx[name] = function (...)
		return ltask.call(ServiceBgfxMain, name, ...)
	end
end

local ServiceWindow = ltask.queryservice "ant.window|window"
ltask.send(ServiceWindow, "subscribe", "init", "exit")
ltask.send(ServiceWindow, "subscribe", "mouse_wheel", "mouse", "touch", "keyboard", "char", "size")
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

local function update_config(cfg, ww, hh)
	cfg.fbw, cfg.fbh = ww, hh
	cfg.viewport = calc_viewport(ww, hh)
end

local function check_size()
	local args = world.args
	if init_width ~= args.fbw or init_height ~= args.fbh then
		update_config(args, init_width, init_height)
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

local function check_load_framebuffer_size(w, h)
	local fbw, fbh = setting:get "graphic/framebuffer/w", setting:get "graphic/framebuffer/h"
	if fbw and fbh then
		return fbw, fbh
	else
		local ratio = setting:get "graphic/framebuffer/ratio"
		if ratio then
			return math.floor(w * ratio + 0.5),
			math.floor(h * ratio + 0.5)
		end
	end
	return w, h
end

function S.init(nwh, context, width, height)
	init_width, init_height = check_load_framebuffer_size(width, height)
	log.info("framebuffer size:", init_width, init_height)
	rhwi.init {
		nwh		= nwh,
		context	= context,
		width	= init_width,
		height	= init_height,
	}
	cr.init()
	bgfx.set_debug "T"
	bgfx.encoder_create()
	bgfx.encoder_init()
	import_package "ant.render".init_bgfx()
	bgfx.encoder_begin()
	encoderBegin = true
	update_config(config, init_width, init_height)
	world = ecs.new_world(config)
	local ev 		= inputmgr.create(world, "win32")
	S.mouse_wheel	= ev.mouse_wheel
	S.mouse 		= ev.mouse
	S.touch			= ev.touch
	S.keyboard		= ev.keyboard
	S.char			= ev.char
	S.size			= function (ww, hh)
		init_width, init_height = check_load_framebuffer_size(ww, hh)
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
