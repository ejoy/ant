local util = {} util.__index = util

-- beg/end : world spcae point
-- color : dword, like 0xffff0000(rgba), mean opacity, blue
-- mode : "line"/"solid"
function util.draw_lines(beg, end, color, transform, mode)
	mode = mode or "solid"
end

-- center : world space point
-- radius : logic unit(1 for 1cm)
function util.draw_sphere(center, radius, color, transform, slices, stacks, mode)
	slices = slices or 10
	stacks = stacks or 10
end

-- width, height, depth : logic unit
function util.draw_rectangle(center, width, height, depth, color, transform, mode)

end

function util.draw_box(center, len, color, transform, mode)
	local full_len = 2 * len
	util.draw_rectangle(center, full_len, full_len, full_len, color, transform, mode)
end

-- len : logic unit, half of then length from head to tail
-- head_radius : logic unit, can be 0
	-- head and tail, one of them can be 0 to become as cone
	-- when head_radius = 0, tail_radius > 0, slices = 3, it become tetrahedron
function util.draw_cylinder(center, len, head_radius, tail_radius, color, transform, slices, mode)
	if tail_raduis == nil then
		tail_radius = assert(head_radius)
	end

	if head_radius == nil then
		head_radius = assert(tail_radius)
	end
	
end

-- 
function util.draw_bone(center, head_len, down_len, color, transform, mode)
	radius = 111
	util.draw_cylinder(center, head_len, 0, radius, color, tranform, mode)
	util.draw_cylinder(center, down_lend, radius, 0, color, tranform, mode)	
end



return util