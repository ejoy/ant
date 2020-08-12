local math3d = require "math3d"

local m = {}
local world
function m.point_to_line_distance2D(p1, p2, p3)
	local dx = p2[1] - p1[1];
	local dy = p2[2] - p1[2];
	if (dx + dy == 0) then
		return math.sqrt((p3[1] - p1[1]) * (p3[1] - p1[1]) + (p3[2] - p1[2]) * (p3[2] - p1[2]));
	end
	local u = ((p3[1] - p1[1]) * dx + (p3[2] - p1[2]) * dy) / (dx * dx + dy * dy);
	if u < 0 then
		return math.sqrt((p3[1] - p1[1]) * (p3[1] - p1[1]) + (p3[2] - p1[2]) * (p3[2] - p1[2]));
	elseif u > 1 then
		return math.sqrt((p3[1] - p2[1]) * (p3[1] - p2[1]) + (p3[2] - p2[2]) * (p3[2] - p2[2]));
	else
		local x = p1[1] + u * dx;
		local y = p1[2] + u * dy;
		return math.sqrt((p3[1] - x) * (p3[1] - x) + (p3[2] - y) * (p3[2] - y));
	end
end

function m.ray_hit_plane(ray, plane_info)
	local plane = {n = plane_info.dir, d = -math3d.dot(math3d.vector(plane_info.dir), math3d.vector(plane_info.pos))}

	local rayOriginVec = ray.origin
	local rayDirVec = ray.dir
	local planeDirVec = math3d.vector(plane.n[1], plane.n[2], plane.n[3])
	
	local d = math3d.dot(planeDirVec, rayDirVec)
	if math.abs(d) > 0.00001 then
		local t = -(math3d.dot(planeDirVec, rayOriginVec) + plane.d) / d
		if t >= 0.0 then
			return math3d.add(ray.origin, math3d.mul(t, ray.dir))
		end	
	end
	return nil
end

function m.view_to_axis_constraint(ray, cameraPos, axis, origin)
	-- find plane between camera and initial position and direction
	--local cameraToOrigin = math3d.sub(cameraPos - math3d.vector(origin[1], origin[2], origin[3]))
	local cameraToOrigin = math3d.sub(cameraPos, origin)
	local axisVec = math3d.vector(axis)
	local lineViewPlane = math3d.normalize(math3d.cross(cameraToOrigin, axisVec))

	-- Now we project the ray from origin to the source point to the screen space line plane
	local cameraToSrc = math3d.normalize(math3d.sub(ray.origin, cameraPos))

	local perpPlane = math3d.cross(cameraToSrc, lineViewPlane)

	-- finally, project along the axis to perpPlane
	local factor = (math3d.dot(perpPlane, cameraToOrigin) / math3d.dot(perpPlane, axisVec))
	return math3d.mul(factor, axisVec)
end


local icamera
local global_data = require "common.global_data"
function m.world_to_screen(camera_eid, world_pos)
	local vp = icamera.calc_viewproj(camera_eid)
	local proj_pos = math3d.totable(math3d.transform(vp, world_pos, 1))
	return {(1 + proj_pos[1] / proj_pos[4]) * global_data.viewport.w * 0.5, (1 - proj_pos[2] / proj_pos[4]) * global_data.viewport.h * 0.5, 0}
end

function m.adjust_mouse_pos(x,y)
    if not global_data.viewport then
        return x, y
    end
    return x - global_data.viewport.x, y - global_data.viewport.y
end

return function(w)
	world = w
	icamera = world:interface "ant.camera|camera"
	return m
end