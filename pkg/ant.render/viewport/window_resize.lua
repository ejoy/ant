local ecs   = ...
local world = ecs.world

local rhwi      = import_package "ant.hwi"
local iviewport = ecs.require "ant.render|viewport.state"
local resize_mb	= world:sub {"resize"}

local winresize_sys = ecs.system "window_resize_system"

local function resize(ww, hh)
	iviewport.resize(ww, hh)
	world:pub{"scene_viewrect_changed", iviewport.viewrect}
end

function winresize_sys:start_frame()
	for _, ww, hh in resize_mb:unpack() do
		rhwi.reset(nil, ww, hh)
		resize(ww, hh)
	end
end


local iwr = {}

function iwr.set_resolution_limits(ww, hh)
	ww, hh = math.min(world.args.width, ww), math.min(world.args.height, hh)
	iviewport.set_resolution_limits(ww, hh)
	local dvr = iviewport.device_viewrect
	resize(dvr.w, dvr.h)
end

return iwr