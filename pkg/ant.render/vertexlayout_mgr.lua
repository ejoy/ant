local rc = import_package "ant.render.core"
local L = rc.layout

local mgr = {
	elem_size 		= L.elem_size,
	layout_stride 	= L.layout_stride,
	correct_elem	= L.correct_elem,
	correct_layout	= L.correct_layout,
	vertex_desc_str = L.vertex_desc_str,
}

local function create_layout(vb_layout)
	local layoutnames = {}
	for e in vb_layout:gmatch("%w+") do
		layoutnames[#layoutnames+1] = L.layout_name(e)
	end

	local bgfx = require "bgfx"
	local d, stride = bgfx.vertex_layout(layoutnames)
	return {handle=d, stride=stride}
end

local LAYOUTS = {}

function mgr.get(layout)
	local l = LAYOUTS[layout]
	if l == nil then
		local newlayout = mgr.correct_layout(layout)

		l = LAYOUTS[newlayout]
		if l == nil then
			l = create_layout(newlayout)
			LAYOUTS[layout]		= l
			LAYOUTS[newlayout]	= l
		end
	end
	return l
end

return mgr