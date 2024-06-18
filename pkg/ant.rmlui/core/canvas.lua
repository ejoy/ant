local ltask = require "ltask"
local bgfx = require "bgfx"
local hwi = import_package "ant.hwi"
local setting   = import_package "ant.settings"
local document_manager = require "core.document_manager"
local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler

local canvas_size = setting:get "canvas"
local canvas_id = hwi.viewid_get "uicanvas"
local canvas_fb

local function create_framebuffer()
	local fb = { rbidx = fbmgr.create_rb {
		w = canvas_size.width,
		h = canvas_size.height,
		layers = 1,
		format = "RGBA8",
		flags = sampler {
			MIN =   "LINEAR",
			MAG =   "LINEAR",
			U   =   "CLAMP",
			V   =   "CLAMP",
			RT  =   "RT_ON",
	    },
	} }
	canvas_fb = fbmgr.create(fb)
	bgfx.set_view_frame_buffer(canvas_id, assert(fbmgr.get(canvas_fb).handle))
	bgfx.set_view_mode(canvas_id, "s")
    bgfx.set_view_rect(canvas_id, 0, 0, canvas_size.width, canvas_size.height)
	bgfx.set_view_clear(canvas_id, "C", 0x000000ff)
	
--	print ("Bind to ", canvas_id)

	local handle = fbmgr.get_rb(fb.rbidx).handle
	return handle
end

local function release_framebuffer(handle)
    local rb_handle = fbmgr.get_rb(canvas_fb, 1).handle
	assert(handle == rb_handle)
	fbmgr.destroy(canvas_fb)
	canvas_fb = nil
end

local S = ltask.dispatch()

function S.load()
	document_manager.ignore_canvas(false)
	local c = {
		info = {
            width = canvas_size.width,
            height = canvas_size.height,
            format = "RGBA8",
            mipmap = false,
            depth = 1,
            numLayers = 1,
            cubeMap = false,
            storageSize = 4,
            numMips = 1,
            bitsPerPixel = 32,
		},
		flag = "+l-lvcucrt",
		handle = create_framebuffer(),
	}
	return c, true
end

function S.unload(handle)
	document_manager.ignore_canvas(true)
	release_framebuffer(handle)
end

local canvas = {}

function canvas.resize(width, height)
	canvas_size.width = width
	canvas_size.height = height
end

function canvas.size()
	return canvas_size.width, canvas_size.height
end

local init
function canvas.init()
	if not init then
		init = true
		local textmgr = ltask.queryservice "ant.resource_manager|resource"
		ltask.call(textmgr, "register", "canvas", ltask.self())
	end
end

return canvas