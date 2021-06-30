local ltask = require "ltask"
local packagename = ...
package.path = "engine/?.lua"
require "bootstrap"

local inputmgr  = import_package "ant.inputmgr"
local ecs       = import_package "ant.ecs"
local rhwi      = import_package "ant.hwi"

local bgfx      = require "bgfx"
local ServiceBgfxMain = ltask.queryservice "bgfx_main"
for _, name in ipairs(ltask.call(ServiceBgfxMain, "APIS")) do
	bgfx[name] = function (...)
		return ltask.call(ServiceBgfxMain, name, ...)
	end
end

local ServiceWindow = ltask.queryservice "window"
ltask.send(ServiceWindow, "subscribe", "init", "exit")

local function initargs(package)
    local fs = require "filesystem"
    local info = fs.dofile(fs.path("/pkg/"..package.."/package.lua"))
    return {
        ecs = info.ecs,
    }
end

local S = {}

local config = initargs(packagename)
local world
local encoderBegin = false

local function Render()
	while true do
		if world then
			world:pipeline_update()
			bgfx.encoder_end()
			encoderBegin = false
			rhwi.frame()
		end
		if world then
			bgfx.encoder_begin()
			encoderBegin = true
		end
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
	bgfx.set_debug "ST"
	bgfx.encoder_init()
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
	ltask.send(ServiceWindow, "subscribe", "mouse_wheel", "mouse", "touch", "keyboard")

	world:pub {"resize", width, height}
	world:pipeline_init()

	ltask.fork(Render)
end
function S.exit()
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
