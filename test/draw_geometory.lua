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
-- radius : logic unit
-- center : center is located in the half length of the cylinder
-- slices : how many face of this cylinder
function util.draw_cylinder(center, len, radius, color, transform, mode, slices)
	
end

-- height : total height of this cone
-- center : located in the bottom on the cone
-- slices : same as cylinder
function util.draw_cone(center, height, color, transform, mode, slices)

end

-- 
function util.draw_bone(center, head_len, down_len, radius, color, transform, mode)	
	util.draw_cone(center, head_len, 0, radius, color, tranform, mode)
	util.draw_cone(center, down_lend, radius, 0, color, tranform, mode)	
end



return util