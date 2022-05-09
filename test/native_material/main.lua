package.path = "engine/?.lua;?.lua"
require "bootstrap"

local window = require "window"

local bgfx = require "bgfx"
local rhwi = import_package "ant.hwi"
local cr = import_package "ant.compile_resource"
local S = {}
local test

function S.init(nwh, context, width, height)
	log.info("framebuffer size:", width, height)

	local framebuffer = {
		width	= width,
		height	= height,
		ratio 	= 1,
		scene_ratio = 1,
	}
	rhwi.init {
		nwh		= nwh,
		context	= context,
		framebuffer = framebuffer,
	}
	cr.init()
	bgfx.set_debug "T"
	--bgfx.encoder_create()
	bgfx.encoder_init()

    test = require "test"
    test.init()
end

local function render()
    test.render()
end

function S.update()
    --world:pipeline_update()
    bgfx.encoder_begin()
	render()
    do
        rhwi.frame()
    end
    --world:pipeline_update_end()
    bgfx.encoder_end()
end

local function dispatch(CMD,...)
    S[CMD](...)
end
window.create(dispatch, 1334, 750)
window.mainloop(true)