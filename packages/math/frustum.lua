-- file only for test purpose

local frustum = {}
frustum.__index = frustum

function frustum.new(f, ms)
	return setmetatable({l=f.l, r=f.r, t=f.t, b=f.b, n=f.n, f=f.f, ms}, frustum)
end

function frustum.from_projmat(proj)
	
end

function frustum:corner_points()
	local half_nw = (self.r - self.l) * 0.5
	local half_nh = (self.b - self.t) * 0.5

	local near, far = self.n, self.f
	local half_fh = (far / near) * half_nh
	local half_fw = (far / near) * half_nw
	
	return{
		nlt = {-half_nw, half_nh, near},
		nrt = {half_nw, half_nh, near},
		nlb = {-half_nw, -half_nh, near },
		nrb = {half_nw, -half_nh, near },

		flt = {-half_fw, half_fh, far},
		frt = {half_fw, half_fh, far},
		flb = {-half_fw, -half_fh, far },
		frb = {half_fw, -half_fh, far },
	}
end

function frustum:create_plane(p0, p1, p2)
	local ms = self.ms
	local n = ms(p0, p1, "-", p0, p2, "-xnT")
	local d = ms(n, p0, ".T")
	return {
		normal = {n[1], n[2], n[3]},
		distance = d[1],
	}	
end

function frustum:construct_frustum_planes()
	local points = self:corner_points()

	return {
		near = self:create_plane(points.nrt, points.nlt, points.nlb),
		far = self:create_plane(points.flt, points.frt, points.frb),

		left = self:create_plane(points.nlt, points.flt, points.flb),
		right = self:create_plane(points.frt, points.nrt, points.nrb),

		top = self:create_plane(points.nrt, points.frt, points.flt),
		bottom = self:create_plane(points.flb, points.frb, points.nrb),
	}
end

function frustum:distance_to_plane(point, plane)
	local dot = self.ms(point, plane.normal, ".T")
	return dot + plane.distance
end

function frustum:point_in_frustum(point, frustum)
	local planes = self:construct_frustum_planes(frustum)

	local on_oneof_surface = false
	for _, plane in pairs(planes) do
		local dis = self:distance_to_plane(point, plane)

		if dis < 0 then
			return "outside"
		end

		if dis == 0 then
			on_oneof_surface = true
		end
	end

	return on_oneof_surface and "onsurface" or "inside"	
end

function frustum:where_sphere(sphere)
	local planes = self:construct_frustum_planes()
	local center = sphere.center
	local has_intersection = false
	for _, plane in pairs(planes) do
		local dis = frustum:distance_to_plane(center, plane)

		if math.abs(dis) <= sphere.radius then
			has_intersection = true
		end

		if dis < 0 then			
			return "outside"
		end
	end

	return has_intersection and "intersection" or "inside"
end

function frustum:is_aabb_in_frustum(aabb)

end

return frustum