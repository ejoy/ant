local ecs   = ...
local world = ecs.world
local w     = world.w

local setting   = import_package "ant.settings"
local mu		= import_package "ant.math".util

local rhwi      = import_package "ant.hwi"

local ENABLE_HVFILP<const> 	= setting:get "graphic/postprocess/hv_flip/enable"

local function update_config(args, ww, hh)
	local vp = {x = 0, y = 0, w = ww, h = hh}
	local resolution = args.scene.resolution
	local scene_ratio = args.scene.scene_ratio
	local vr = mu.get_scene_view_rect(resolution.w ,resolution.h, vp, scene_ratio)
	if ENABLE_HVFILP then
		vp.w, vp.h = hh, ww
	else
		vp.w, vp.h = ww, hh
	end
	args.scene.viewrect = vr
	args.device_size = vp
end

local resize_mb			= world:sub {"resize"}
local ratio_change_mb	= world:sub {"framebuffer_ratio_changed"}

local winresize_sys = ecs.system "window_resize_system"

if not __ANT_EDITOR__ then
	local function winsize_update(s)
		update_config(world.args, s.w, s.h)
		rhwi.reset(nil, s.w, s.h)
		local vp = world.args.device_size
		local vr = world.args.scene.viewrect
		log.info("device_size:", vp.x, vp.y, vp.w, vp.h)
		log.info("main viewrect:", vr.x, vr.y, vr.w, vr.h)
		world:pub{"scene_viewrect_changed", vr}
	end

	function winresize_sys:init_world()
		local vp = world.args.device_size
		winsize_update({w=vp.w, h=vp.h})
	end

	function winresize_sys:start_frame()
		for _, ww, hh in resize_mb:unpack() do
			winsize_update({w=ww, h=hh})
		end

		for _, which, ratio in ratio_change_mb:unpack() do
			local _ = which == "scene_ratio" or error ("Invalid ratio type:" .. which)
			world:pub{"scene_ratio_changed", ratio}
		end
	end
end
