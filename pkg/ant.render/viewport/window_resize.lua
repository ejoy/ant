local ecs   = ...
local world = ecs.world
local w     = world.w

local setting   = import_package "ant.settings".setting
local mu		= import_package "ant.math".util

local rhwi      = import_package "ant.hwi"

local ENABLE_HVFILP<const> 	= setting:get "graphic/postprocess/hv_flip/enable"

local SCENE_RATIO<const> 	= setting:get "framebuffer/scene_ratio" or 1.0
local RATIO<const> 			= setting:get "framebuffer/ratio" 		or 1.0

world.args.framebuffer.ratio 		= RATIO
world.args.framebuffer.scene_ratio 	= SCENE_RATIO
log.info(("framebuffer ratio:%2f, scene:%2f"):format(RATIO, SCENE_RATIO))

local function update_config(args, ww, hh)
	local fb = args.framebuffer
	fb.width, fb.height = ww, hh

	local vp = args.viewport
	if vp == nil then
		vp = {}
		args.viewport = vp
	end

	vp.x, vp.y = 0, 0
	if ENABLE_HVFILP then
		vp.w, vp.h = hh, ww
	else
		vp.w, vp.h = ww, hh
	end
end

local function calc_fb_size(ww, hh, ratio)
	return mu.cvt_size(ww, ratio), mu.cvt_size(hh, ratio)
end

local resize_mb = world:sub {"resize"}

local winresize_sys = ecs.system "window_resize_system"

function winresize_sys:start_frame()
	if world.args.disable_resize then
		return 
	end
	for _, ww, hh in resize_mb:unpack() do
		local nww, nhh = calc_fb_size(ww, hh, world.args.framebuffer.ratio)
		log.info("resize framebuffer from:", ww, hh, ", to:", nww, nhh)
		update_config(world.args, nww, nhh)
		rhwi.reset(nil, nww, nhh)
		local vp = world.args.viewport
		log.info("main viewport:", vp.x, vp.y, vp.w, vp.h, vp.ratio or "(viewport ratio is nil)")
		world:pub{"world_viewport_changed", vp}
	end
end