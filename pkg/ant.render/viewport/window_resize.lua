local ecs   = ...
local world = ecs.world
local w     = world.w

local setting   = import_package "ant.settings"
local mu		= import_package "ant.math".util

local rhwi      = import_package "ant.hwi"
local iviewport = ecs.require "ant.render|viewport.state"
local resize_mb	= world:sub {"resize"}

local winresize_sys = ecs.system "window_resize_system"

local function log_viewrect()
	local vr = iviewport.viewrect
	local dvr = iviewport.device_viewrect
	log.info("device_size:", 	dvr.x, dvr.y, dvr.w, dvr.h)
	log.info("main viewrect:",	vr.x, vr.y, vr.w, vr.h)
end

function winresize_sys:init_world()
	log_viewrect()
end

function winresize_sys:start_frame()
	for _, ww, hh in resize_mb:unpack() do
		iviewport.resize(ww, hh)
		rhwi.reset(nil, ww, hh)

		world:pub{"scene_viewrect_changed", iviewport.viewrect}
	end
end
