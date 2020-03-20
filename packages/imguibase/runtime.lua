local window = require "window"

local renderpkg = import_package "ant.render"
local argument  = import_package "ant.argument"
local thread    = require "thread"
local rhwi      = renderpkg.hwi
local debug_traceback = debug.traceback
local thread_sleep = thread.sleep

local keymap    = require "keymap"
local mouse_what = { 'LEFT', 'RIGHT', 'MIDDLE' }
local mouse_state = { 'DOWN', 'MOVE', 'UP' }

local LOGERROR = __ANT_RUNTIME__ and log.error or print
local debug_update = __ANT_RUNTIME__ and require 'runtime.debug'

local callback = {}

local config
local world
local world_update

function callback.init(nwh, context, width, height)
	rhwi.init {
		nwh = nwh,
		context = context,
		width = width,
		height = height,
	}
	config.width  = width
	config.height = height
	local su = import_package "ant.scene".util
	world = su.create_world()
	world.init(config)
end

function callback.mouse(x, y, what, state)
	world.mouse(x, y, mouse_what[what] or "UNKNOWN", mouse_state[state] or "UNKNOWN")
end
function callback.touch(x, y, id, state)
	world.touch(x, y, mouse_state[state] or "UNKNOWN", id)
end
function callback.keyboard(key, press, state)
	world.keyboard(keymap[key], press, {
		CTRL 	= (state & 0x01) ~= 0,
		ALT 	= (state & 0x02) ~= 0,
		SHIFT 	= (state & 0x04) ~= 0,
		SYS 	= (state & 0x08) ~= 0,
	})
end
function callback.size(width,height,_)
	world.size(width,height)
	rhwi.reset(nil, width, height)
end

function callback.exit()
	world.exit()
	rhwi.shutdown()
    print "exit"
end

function callback.update()
	if debug_update then debug_update() end
	if world then
		world.update()
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
	window.create(run, 1024, 768)
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

local function initargs(package)
	local fs = require "filesystem"
	local package_config = fs.dofile(fs.path("/pkg/"..package.."/package.lua"))
	return package_config.world
end

local function start(package)
	config = initargs(package)
	if argument.headless then
		return headlessMode()
	end
	return windowMode()
end

return {
	start = start,
	callback = callback,
}
