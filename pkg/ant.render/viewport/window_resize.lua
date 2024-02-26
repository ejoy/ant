local ecs   = ...
local world = ecs.world

local rhwi      = import_package "ant.hwi"
local iviewport = ecs.require "ant.render|viewport.state"
local resize_mb	= world:sub {"resize"}

local winresize_sys = ecs.system "window_resize_system"

function winresize_sys:start_frame()
	for _, ww, hh in resize_mb:unpack() do
		iviewport.resize(ww, hh)
		rhwi.reset(nil, ww, hh)

		world:pub{"scene_viewrect_changed", iviewport.viewrect}
	end
end
