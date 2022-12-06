local geometry = {}; geometry.__index = geometry

--[[
	box

	ltf---------rtf
	/|			/|
   / |		   / |
  ltn--------rtn |
   |lbf-------|-rbf
   | /		  | /
   |/		  |/
  lbn--------rbn
]]


local function create_box_ib(needib, line)
	if needib then
		if line then
			return {
				0, 1,
				1, 2,
				2, 3,
				3, 0,
			
				4, 5,
				5, 6,
				6, 7,
				7, 4,
			
				0, 7,
				1, 6,
				2, 5,		
				3, 4,
			}
			
		else
			local
			lbn<const>, ltn<const>, rtn<const>, rbn<const>,
			rbf<const>, rtf<const>, ltf<const>, lbf<const> = 
					0, 1, 2, 3,
					4, 5, 6, 7

			local faces<const> = {
				{lbn, ltn, rtn, rbn},	--front
				{rbf, rtf, ltf, lbf},	--back

				{lbf, ltf, ltn, lbn},	--left
				{rbn, rtn, rtf, rbf},	--right

				{ltn, ltf, rtf, rtn},	--top
				{rbn, rbf, lbf, lbn},	--bottom
			}

			local subib<const> = {
				1, 2, 4,
				2, 3, 4
			}
			local ib = {}
			for _, f in ipairs(faces) do
				for _, si in ipairs(subib) do
					ib[#ib+1] = f[si]
				end
			end

			return ib
		end
	end
end	

function geometry.box_from_aabb(aabb, needib, line)
	local function create_vb()
		if aabb then
			local min, max = aabb.min, aabb.max

			local maxx, maxy, maxz = max[1], max[2], max[3]
			local minx, miny, minz = min[1], min[2], min[3]
			return {
					min[1], min[2], min[3],	-- lbn
					minx, maxy, minz,		-- ltn
					maxx, maxy, minz,		-- rtn
					maxx, miny, minz,		-- rbn
		
					maxx, miny, maxz,		-- rbf
					max[1], max[2], max[3],	-- rtf
					minx, maxy, maxz,		-- ltf
					minx, miny, maxz,		-- lbf
				}
		end
	end
	return create_vb(), create_box_ib(needib, line)
end

function geometry.box(size, needib, line)
	local function create_vb()
		if size then
			local hsx, hsy, hsz
			if type(size) == "table" then
				hsx, hsy, hsz = size[1], size[2], size[3]
			else
				hsx, hsy, hsz = size, size, size
			end

			return {
				-hsx, -hsy, -hsz,	-- lbn
				-hsx, hsy, -hsz,	-- ltn
				hsx, hsy, -hsz,		-- rtn
				hsx, -hsy, -hsz,	-- rbn
	
				hsx, -hsy, hsz,		-- rbf
				hsx, hsy, hsz,		-- rtf
				-hsx, hsy, hsz,		-- ltf
				-hsx, -hsy, hsz,	-- lbf
			}
		end

	end

	return create_vb(), create_box_ib(needib, line)
end

local function add_vertex(t, x, y, z)
	local n = #t
	t[n+1], t[n+2], t[n+3] = x, y, z
end

local function gen_circle_vertices(vb, slices, height, radius)
	local radian_step = 2 * math.pi / slices
	for s=0, slices-1 do
		local radian = radian_step * s
		add_vertex(vb, 
			math.cos(radian) * radius,
			height,
			math.sin(radian) * radius)
	end
end

local function gen_circle_vertices_facez(vb, slices, zvalue, radius, arc_desc)
	local arc = arc_desc or {start_deg = 0, end_deg = 2 * math.pi }
	local radian_step = (arc.end_deg - arc.start_deg) / slices
	local step_count = arc_desc and slices or slices-1
	for s=0, step_count do
		local radian = arc.start_deg + radian_step * s
		add_vertex(vb,
			math.cos(radian) * radius,
			math.sin(radian) * radius,
			zvalue)
	end
end

local function gen_circle_indices(ib, slices, baseidx, arc)
	local last_idx = baseidx
	local end_idx = arc and slices or baseidx
	for i=1, slices do
		local next_idx = i == slices and end_idx or (last_idx + 1)				
		ib[#ib+1] = last_idx
		ib[#ib+1] = next_idx

		last_idx = next_idx
	end
end

function geometry.circle(radius, slices, arc)
	local vb = {}
	local ib = {}
	gen_circle_vertices_facez(vb, slices, 0, radius, arc)
	gen_circle_indices(ib, slices, 0, arc)
	return vb, ib
end

function geometry.cone(slices, height, radius, needib, line)
	local function create_vb()
		if height and radius then			
			if slices < 3 then
				error(string.format("need at least 3 slices, %d given", slices))
				return 
			end

			local vb = {
				0, height, 0,	-- top center
				0, 0, 0			-- bottom center
			}
			gen_circle_vertices(vb, slices, 0, radius)
			return vb
		end
	end

	local function create_ib()
		if needib then
			if line then
				local ib = {}
				
				local topcenter_idx, bottomcenter_idx = 0, 1
				
				for i=1, slices do
					-- height lines
					ib[#ib+1] = topcenter_idx
					ib[#ib+1] = bottomcenter_idx + i

					-- bottom lines
					ib[#ib+1] = bottomcenter_idx
					ib[#ib+1] = bottomcenter_idx + i
				end

				-- circles lines
				gen_circle_indices(ib, slices, bottomcenter_idx + 1)

				return ib
			end
		end
	end

	return create_vb(), create_ib()
end

function geometry.cylinder(slices, height, radius, needib, line)
	local function create_vb()
		if height and radius then			
			if slices < 3 then
				error(string.format("need at least 3 slices, %d given", slices))
				return 
			end

			local half_height = height * 0.5			

			local vb = {
				0, half_height, 0,	-- top center
			}

			gen_circle_vertices(vb, slices, half_height, radius)

			add_vertex(vb, 0, -half_height, 0)	-- bottom center
			gen_circle_vertices(vb, slices, -half_height, radius)
			return vb
		end
	end

	local function create_ib()
		if needib then
			if line then
				local ib = {}
				local topcenter_idx, bottomcenter_idx = 0, slices
				
				for i=1, slices do
					-- top lines
					ib[#ib+1] = topcenter_idx
					ib[#ib+1] = topcenter_idx+i

					-- body lines
					ib[#ib+1] = topcenter_idx+i
					ib[#ib+1] = bottomcenter_idx+i

					-- bottom lines
					ib[#ib+1] = bottomcenter_idx
					ib[#ib+1] = bottomcenter_idx+i
				end

				gen_circle_indices(ib, slices, topcenter_idx+1)
				gen_circle_indices(ib, slices, bottomcenter_idx+1)
			end
		end
	end

	return create_vb(), create_ib()
end

local function icosahedron()
	local gr = (1 + math.sqrt(5)) * 0.5	-- golden ratio
	local vb = {
		{-1.0,  gr, 0.0},
		{ 1.0,  gr, 0.0},
		{-1.0, -gr, 0.0},
		{ 1.0, -gr, 0.0},
		{0.0, -1.0,  gr},
		{0.0,  1.0,  gr},
		{0.0, -1.0, -gr},
		{0.0,  1.0, -gr},
		{ gr, 0.0, -1.0},
		{ gr, 0.0,  1.0},
		{-gr, 0.0, -1.0},
		{-gr, 0.0,  1.0},
	}

	local ib = {
		0, 11, 5,
		0, 5, 1,
		0, 1, 7,
		0, 7, 10,
		0, 10, 11,
		1, 5, 9,
		5, 11, 4,
		11, 10, 2,
		10, 7, 6,
		7, 1, 8,
		3, 9, 4,
		3, 4, 2,
		3, 2, 6,
		3, 6, 8,
		3, 8, 9,
		4, 9, 5,
		2, 4, 11,
		6, 2, 10,
		8, 6, 7,
		9, 8, 1,
	}

	return vb, ib
end

local function octahedron(radius)
	local vb = {
		0, radius, 0, -- top
		radius, 0, 0,
		0, 0, -radius,
		-radius, 0, 0,
		0, 0, radius,
		0, -radius, 0,	-- bottom
	}

	local ib = {
		-- top
		0, 1, 2,
		0, 2, 3,
		0, 3, 4,
		0, 4, 1,

		-- bottom
		5, 1, 4,
		5, 4, 3,
		5, 3, 2, 
		5, 2, 1,
	}

	return vb, ib
end

local function triangle_index_to_line_index(ib)
	local line_ib = {}

	local cache = {}
	
	for i=1, #ib, 3 do
		local p0 = {ib[i+0], ib[i+1]}
		local p1 = {ib[i+1], ib[i+2]}
		local p2 = {ib[i+2], ib[i+0]}

		local function haskey(p)
			local k0, k1 = p[1] .. "," .. p[2], p[2] .. "," .. p[1]
			return cache[k0] or cache[k1]
		end

		for _, p in ipairs {p0,p1,p2} do
			if not haskey(p) then
				local k = p[1] .. "," .. p[2]
				cache[k] = true
				table.insert(line_ib, p[1])
				table.insert(line_ib, p[2])
			end			
		end

	end

	return line_ib	
end

local function tessellateion(vb, ib, radius)
	local newvb, newib = {}, {}

	local numfaces = #ib / 3
	for f=0, numfaces-1 do
		local function get_v(idx)
			local i = ib[f*3+idx]
			return {vb[i+1], vb[i+2], vb[i+3]}
		end
		
		local v0, v1, v2 = get_v(1), get_v(2), get_v(3)
		local function middle(v0, v1)
			local t = {}
			for i=1, 3 do
				table.insert(t, 0.5 * (v0[i] + v1[i]))
			end

			local l = math.sqrt(t[1] * t[1] + t[2] * t[2] + t[3] * t[3])
			local factor = radius / l
			t[1] = t[1] * factor
			t[2] = t[2] * factor
			t[3] = t[3] * factor
			return t
		end

		local m0, m1, m2 = middle(v0, v1), middle(v1, v2), middle(v2, v0)

--[[
	        v0
			/\
		m2 /__\ m0
		  / \/ \
		 /___|__\
		v2  m1  v1
]]
		local vertexnum = #newvb / 3
		add_vertex(newvb, v0[1], v0[2], v0[3])
		add_vertex(newvb, v1[1], v1[2], v1[3])
		add_vertex(newvb, v2[1], v2[2], v2[3])


		add_vertex(newvb, m0[1], m0[2], m0[3])
		add_vertex(newvb, m1[1], m1[2], m1[3])
		add_vertex(newvb, m2[1], m2[2], m2[3])

		local newindices = {
			0, 3, 5,
			1, 4, 3, 
			3, 4, 5,
			2, 5, 4,
		}

		for i=1, #newindices do
			newindices[i] = newindices[i] + vertexnum
		end
		table.move(newindices, 1, #newindices, #newib+1, newib)
	end

	return newvb, newib

end

function geometry.sphere(tessellation, radius, needib, line)
	-- octahedron
	-- icosahedron

	local needvb = radius ~= nil

	radius = radius or 1
	local vb, ib = octahedron(radius)
	for _=2, tessellation do
		vb, ib = tessellateion(vb, ib, radius)
	end

	if not needvb then
		vb = nil
	end

	if needib then
		if line then
			return vb, triangle_index_to_line_index(ib)
		end
		return vb, ib
	end
	return vb
end

function geometry.capsule(radius, height, tessellation)
	local t_vb = {
		      0, radius,   0,
		 radius, 0,        0,
		      0, 0,  -radius,
		-radius, 0,        0,
		      0, 0,   radius,
	}
	local b_vb = {
		      0, -radius,  0,
		 radius, 0,        0,
		      0, 0,  -radius,
		-radius, 0,        0,
		      0, 0,   radius,
	}
	local t_ib = {
		0, 1, 2,
		0, 2, 3,
		0, 3, 4,
		0, 4, 1,
	}
	local b_ib = {
		0, 1, 2,
		0, 2, 3,
		0, 3, 4,
		0, 4, 1,
	}
	for _=2, tessellation do
		t_vb, t_ib = tessellateion(t_vb, t_ib, radius)
		b_vb, b_ib = tessellateion(b_vb, b_ib, radius)
	end

	local h = height / 2
	local mark = {}
	local middle = {}
	for i=1, #t_vb, 3 do
		local y = t_vb[i+2]
		if y < 0.001 and y > -0.001 then
			middle[#middle+1] = i - 1
		end
		t_vb[i+2] = y + h
	end

	for i=1, #b_vb, 3 do
		b_vb[i+2] = b_vb[i+2] - h
	end

	local vb, ib = t_vb, t_ib
	local offset = #vb / 3
	for i = 1, #b_ib do
		b_ib[i] = b_ib[i] + offset
	end
    local function table_append(t, a)
        table.move(a, 1, #a, #t+1, t)
	end
	table_append(vb, b_vb)
	table_append(ib, b_ib)
	ib = triangle_index_to_line_index(ib)
	for _, t in ipairs(middle) do
		ib[#ib+1] = t
		ib[#ib+1] = t + offset
	end
	return vb, ib
end

function geometry.sphereLatitude(slices, stacks, radius, needib, line)

end

function geometry.grid(width, height, color, unit)
	if width < 2 or height < 2 then
		return
	end

	local function is_even_number(num)
		local half = num * 0.5
		return math.floor(half) == half
	end	

	if not is_even_number(width) or not is_even_number(height) then
		error(string.format("width = %d, height = %d, all need to even number", width, height))
	end

	local vb, ib = {}, {}
	local function add_vertex_clr(x, z, clr)
		add_vertex(vb, x, 0, z)
		vb[#vb+1] = clr
	end

	local hw = width * 0.5
	local hw_len = hw * unit

	local hh = height * 0.5
	local hh_len = hh * unit

	color = color or 0x88c0c0c0

	local function add_line(x0, z0, x1, z1, color)
		add_vertex_clr(x0, z0, color)
		add_vertex_clr(x1, z1, color)
		-- call 2 times
		table.insert(ib, #ib)
		table.insert(ib, #ib)
	end

	-- column lines
	for i=0, width do
		local x = -hw_len + i * unit
		add_line(x, -hh_len, x, hh_len, color)
	end

	-- row lines
	for i=0, height do
		local y = -hh_len + i * unit
		add_line(-hw_len, y, hw_len, y, color)
	end

	-- center lines
	add_line(-hh_len, 0, hh_len, 0, color--[[0x880000ff]])
	add_line(0, -hw_len, 0, hw_len, color--[[0x88ff0000]])
	return vb, ib
end

function geometry.to_line_indices(tri_indices)
	local indices = {}

	for it=1, #tri_indices, 3 do
		local v1, v2, v3 = tri_indices[it], tri_indices[it+1], tri_indices[it+2]
		indices[#indices+1] = v1
		indices[#indices+1] = v2

		indices[#indices+1] = v2
		indices[#indices+1] = v3

		indices[#indices+1] = v3
		indices[#indices+1] = v1
	end

	return indices
end

function geometry.tetrahedron(r, color, cross)
	assert(type(color) == "number")
	if cross then
		--one edge is align z-axis, one edge is parallel to x-axis
		--origin point in center of z-axis
		local a = (math.sqrt(6.0)/3.0)*r
		local ch = math.sqrt(2)*a

		local bd = ch

		return {
			 0, 0,  a, color,
			 0, 0, -a, color,
			 a,-bd, 0, color,
			-a,-bd, 0, color,
		},{
			0, 2, 1,
			0, 1, 3,
			0, 3, 2,
			1, 2, 3,
		}
	else
		--[[
			set outter sphere radius: 'r'
			set sphere origin: (0, 0, 0)
			set tetrahedron height and edge: h, e
			so origin to bottom face: d = h - r
			bottom face to origin distance: d
			set bottom face radius: 'c'
			so: c = (2*sqrt(2)/3) * r
				d = (1/3) * r
				b = c/2 = (sqrt(2)/3)*r
				a = (sqrt(6)/3)*r
			so top vertex is: (0, r, 0)
			vertex in z-axis is: (0.0, -d, c) = (0, -1/3*r, (2*sqrt(2)/3)*r)
			another 2 vertices:
				(-a, -d, -b) = (-sqrt(6)/3*r, -1/3*r, -(sqrt(2)/3)*r)
				( a, -d, -b) = ( sqrt(6)/3*r, -1/3*r, -(sqrt(2)/3)*r)
		]]
		local c = (2*math.sqrt(2.0)/3.0)*r
		local d = (1.0/3.0)*r
		local b = c * 0.5
		local a = (math.sqrt(6.0)/3.0)*r
		return {
			 0, r, 0, color,
			 0,-d, c, color,
			-a,-d,-b, color,
			 a,-d,-b, color,
		}, {
			0, 3, 2,
			0, 1, 3,
			0, 2, 1,
			1, 2, 3,
		}
	end

end

return geometry