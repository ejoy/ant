local ecs   = ...
local world = ecs.world
local w     = world.w

local setting   = import_package "ant.settings"
local mu		= import_package "ant.math".util

local rhwi      = import_package "ant.hwi"
local iviewport = ecs.require "ant.render|viewport.state"

local ENABLE_HVFILP<const> 	= setting:get "graphic/postprocess/hv_flip/enable"

local function update_config(ww, hh)
	--local vp = {x = 0, y = 0, w = ww, h = hh}
	-- local resolution = iviewport.resolution
	-- local scene_ratio = iviewport.scene_ratio
	-- local vr = mu.get_scene_view_rect(resolution, vp, scene_ratio)
	local device_vr = iviewport.device_viewrect
	if ENABLE_HVFILP then
		device_vr.w, device_vr.h = hh, ww
	else
		device_vr.w, device_vr.h = ww, hh
	end
	iviewport.viewrect = iviewport.calc_scene_viewrect()
end

local resize_mb			= world:sub {"resize"}

local winresize_sys = ecs.system "window_resize_system"

local function winsize_update(s)
	update_config(s.w, s.h)

	local vp = iviewport.device_viewrect
	rhwi.reset(nil, s.w, s.h)
	
	local vr = iviewport.viewrect
	log.info("device_size:", vp.x, vp.y, vp.w, vp.h)
	log.info("main viewrect:", vr.x, vr.y, vr.w, vr.h)
	world:pub{"scene_viewrect_changed", vr}
	world:pub{"device_viewrect_changed", vp}
end

function winresize_sys:init_world()
	winsize_update(iviewport.device_viewrect)
end

function winresize_sys:start_frame()
	for _, ww, hh in resize_mb:unpack() do
		winsize_update{w=ww, h=hh}
	end
end
