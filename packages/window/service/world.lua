local ltask = require "ltask"
local packagename = ...
package.path = "engine/?.lua"
require "bootstrap"

local inputmgr  = import_package "ant.inputmgr"
local ecs       = import_package "ant.luaecs"
local rhwi      = import_package "ant.hwi"
local cr        = import_package "ant.compile_resource"

local bgfx      = require "bgfx"
local ServiceBgfxMain = ltask.queryservice "ant.render|bgfx_main"
for _, name in ipairs(ltask.call(ServiceBgfxMain, "APIS")) do
	bgfx[name] = function (...)
		return ltask.call(ServiceBgfxMain, name, ...)
	end
end

local ServiceWindow = ltask.queryservice "ant.window|window"
ltask.send(ServiceWindow, "subscribe", "init", "exit")

local function initargs(package)
    local info = dofile("/pkg/"..package.."/package.lua")
    return {
        ecs = info.ecs,
    }
end

local S = {}

local config = initargs(packagename)
local world
local encoderBegin = false
local quit

local function Render()
	while true do
		world:pipeline_update()
		bgfx.encoder_end()
		encoderBegin = false
		do
			--local _ <close> = world:cpu_stat "bgfx.frame"
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
	rhwi.init {
		nwh = nwh,
		context = context,
		width = width,
		height = height,
	}
	cr.init()
	--bgfx.set_debug "ST"
	bgfx.encoder_init()
	import_package "ant.render".init_bgfx()
	bgfx.encoder_begin()
	ltask.call(ServiceBgfxMain, "encoder_init")
	encoderBegin = true
	config.width  = width
	config.height = height
	world = ecs.new_world(config)
	local ev = inputmgr.create(world)
	S.mouse_wheel = ev.mouse_wheel
	S.mouse = ev.mouse
	S.touch = ev.touch
	S.keyboard = ev.keyboard
	S.size = ev.size
	ltask.send(ServiceWindow, "subscribe", "mouse_wheel", "mouse", "touch", "keyboard","size")

	world:pub {"resize", width, height}
	world:pipeline_init()

	ltask.fork(Render)
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
	ltask.call(ServiceBgfxMain, "encoder_release")
	ltask.send(ServiceWindow, "unsubscribe_all")
	rhwi.shutdown()
	ltask.quit()
    print "exit"
end

S.message = function(...)
	world:pub {"task-message", ...}
end

return S
