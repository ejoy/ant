local window = require "window"

local renderpkg = import_package "ant.render"
local argument  = import_package "ant.argument"
local thread    = require "thread"
local inputmgr  = require "inputmgr"
local keymap    = require "keymap"
local rhwi      = renderpkg.hwi
local debug_traceback = debug.traceback
local thread_sleep = thread.sleep

local LOGERROR = __ANT_RUNTIME__ and log.error or print
local debug_update = __ANT_RUNTIME__ and require 'runtime.debug'

local callback = {}

local conifg
local world
local world_update

function callback.init(nwh, context, width, height)
	rhwi.init {
		nwh = nwh,
		context = context,
		width = width,
		height = height,
	}
	local su = import_package "ant.scene".util
	world = su.start_new_world(width, height, conifg)
	world_update = su.loop(world)
end

function callback.mouse_wheel(x, y, delta)
	world:pub {"mouse_wheel", delta, x, y}
end

function callback.mouse(x, y, what, state)
	world:pub {"mouse", inputmgr.translate_mouse_button(what), inputmgr.translate_mouse_state(state), x, y}
end

function callback.touch(x, y, id, state)
	world:pub {"touch", inputmgr.translate_mouse_state(state), id, x, y }
end

function callback.keyboard(key, press, state)
	world:pub {"keyboard", keymap[key], press, inputmgr.translate_key_state(state)}
end

function callback.size(width,height,_)
	if world then
		world:pub {"resize", width, height}
	end
	rhwi.reset(nil, width, height)
end

function callback.exit()
	if world then
		world:update_func "exit" ()
	end
	rhwi.shutdown()
    print "exit"
end

function callback.update()
	if debug_update then debug_update() end
	if world_update then
		world_update()
		rhwi.frame()
	end
end

local function dispatch(ok, CMD, ...)
	if not ok then
		local ok, err = xpcall(callback.update, debug_traceback)
		if not ok then
			LOGERROR(err)
			if err:find("interrupted!", 1, true) then
				dispatch(true, 'exit')
				window.exit()
				return false
			end
		end
		thread_sleep(0)
		return true
	end
	local f = callback[CMD]
	if f then
		local ok, err = xpcall(f, debug_traceback, ...)
		if not ok then
			LOGERROR(err)
		end
	end
	return CMD ~= 'exit'
end

local function run()
	local window = require "common.window"
	while dispatch(window.recvmsg()) do
	end
end

local function windowMode()
	local window = require "common.window"
	window.create(run, 1024, 768, "Hello")
end

local function savebmp(name, width, height, pitch, data)
	if not name then
		return
	end
	local size = pitch * height
	local patternBITMAPFILEHEADER <const> = "<c2I4I2I2I4"
	local patternBITMAPINFOHEADER <const> = "<I4i4i4I2I2I4I4i4i4I4I4"
	local f = assert(io.open(name, "wb"))
	f:write(patternBITMAPFILEHEADER:pack(
		--[[BITMAPFILEHEADER::bfType         ]]   "BM"
		--[[BITMAPFILEHEADER::bfSize         ]] , patternBITMAPFILEHEADER:packsize() + patternBITMAPINFOHEADER:packsize() + size
		--[[BITMAPFILEHEADER::bfReserved1    ]] , 0
		--[[BITMAPFILEHEADER::bfReserved2    ]] , 0
		--[[BITMAPFILEHEADER::bfOffBits      ]] , patternBITMAPFILEHEADER:packsize() + patternBITMAPINFOHEADER:packsize()
	))
	f:write(patternBITMAPINFOHEADER:pack(
		--[[BITMAPINFOHEADER::biSize         ]]   patternBITMAPINFOHEADER:packsize()
		--[[BITMAPINFOHEADER::biWidth        ]] , width
		--[[BITMAPINFOHEADER::biHeight       ]] , -height
		--[[BITMAPINFOHEADER::biPlanes       ]] , 1
		--[[BITMAPINFOHEADER::biBitCount     ]] , 32 --TODO
		--[[BITMAPINFOHEADER::biCompression  ]] , 0
		--[[BITMAPINFOHEADER::biSizeImage    ]] , size
		--[[BITMAPINFOHEADER::biXPelsPerMeter]] , 0
		--[[BITMAPINFOHEADER::biYPelsPerMeter]] , 0
		--[[BITMAPINFOHEADER::biClrUsed      ]] , 0
		--[[BITMAPINFOHEADER::biClrImportant ]] , 0
	))
	f:write(data)
	f:close()
end

local function screenshot(name)
	savebmp(name, renderpkg.util.screen_capture(world, true))
	--local bgfx = require "bgfx"
	--bgfx.request_screenshot(nil, name)
	--bgfx.frame()
	--bgfx.frame()
	--savebmp(bgfx.get_screenshot())
end

local function headlessMode()
	callback.init(nil, nil, 1024, 768)
	if debug_update then debug_update() end
	if world_update then world_update() end
	screenshot(type(argument.headless) == "string" and  argument.headless or "test.bmp")
	callback.exit()
end

local function start(cfg)
	conifg = cfg
	if argument.headless then
		return headlessMode()
	end
	return windowMode()
end

return {
	start = start,
	callback = callback,
}
