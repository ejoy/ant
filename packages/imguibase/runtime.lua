local window = require "window"

local renderpkg = import_package "ant.render"
local argument  = import_package "ant.argument"
local ecs       = import_package "ant.ecs"
local thread    = require "thread"
local common    = require "common"
local rhwi      = renderpkg.hwi
local debug_traceback = debug.traceback
local thread_sleep = thread.sleep

local LOGERROR = __ANT_RUNTIME__ and log.error or print
local debug_update = __ANT_RUNTIME__ and nil --require 'runtime.debug'

local callback = {}

local config = {}
local world
local world_update
local world_exit

function callback.init(nwh, context, width, height)
	rhwi.init {
		nwh = nwh,
		context = context,
		width = width,
		height = height,
	}
	config.width  = width
	config.height = height
	world = ecs.new_world(config)
	common.init_world(world)
	world:pub {"resize", width, height}
	local irender = world:interface "ant.render|irender"
	irender.create_blit_queue{w=width,h=height}

	world:update_func "init" ()
	world_update = world:update_func "update"
	world_exit   = world:update_func "exit"
end

function callback.mouse_wheel(x, y, delta)
	world:signal_emit("mouse_wheel", x, y, delta)
end
function callback.mouse(x, y, what, state)
	world:signal_emit("mouse", x, y, what, state)
end
function callback.touch(x, y, id, state)
	world:signal_emit("touch", x, y, id, state)
end
function callback.keyboard(key, press, state)
	world:signal_emit("keyboard", key, press, state)
end
function callback.char(...)
	world:signal_emit("char", ...)
end
function callback.size(width,height,_)
	if world then
		world:pub {"resize", width, height}
	end
	rhwi.reset(nil, width, height)
end

function callback.exit()
	if world_exit then
		world_exit()
	end
	rhwi.shutdown()
    print "exit"
end

function callback.update()
	if debug_update then debug_update() end
	if world_update then
		world_update()
		world:clear_removed()
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
			if CMD == "init" then
				return false
			end
		end
	end
	return CMD ~= 'exit'
end

local function run()
	local window = require "window_thread"
	while dispatch(window.recvmsg()) do
	end
end

local function windowMode(w, h)
	local window = require "window_thread"
	window.create(run, w or 1024, h or 768)
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
	local irender = world:interface "ant.render|irender"
	savebmp(name, irender.screen_capture(true))
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
	local info = fs.dofile(fs.path("/pkg/"..package.."/package.lua"))
	return {
		ecs = info.ecs,
	}
end

local function start(package, w, h)
	config = initargs(package)
	if argument.headless then
		return headlessMode()
	end
	return windowMode(w, h)
end

return {
	start = start,
	callback = callback,
}
