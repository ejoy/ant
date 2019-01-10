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
			assert(false)
			return nil
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
					min,				-- lbn
					{minx, maxy, minz},	-- ltn
					{maxx, maxy, minz},	-- rtn
					{maxx, miny, minz},	-- rbn
		
					{maxx, miny, maxz},	-- rbf
					max,				-- rtf
					{minx, maxy, maxz},	-- ltf
					{minx, miny, maxz},	-- lbf			
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
				{-hsx, -hsy, -hsz},	-- lbn
				{-hsx, hsy, -hsz},	-- ltn
				{hsx, hsy, -hsz},	-- rtn
				{hsx, -hsy, -hsz},	-- rbn
	
				{hsx, -hsy, hsz},	-- rbf
				{hsx, hsy, hsz},	-- rtf
				{-hsx, hsy, hsz},	-- ltf
				{-hsx, -hsy, hsz},	-- lbf
			}
		end

	end

	return create_vb(), create_box_ib(needib, line)
end

local function gen_cricle_vertices(vb, slices, height, radius)
	local radian_step = 2 * math.pi / slices
	for s=0, slices-1 do
		local radian = radian_step * s
		table.insert(vb, {
			math.cos(radian) * radius, 
			height,
			math.sin(radian) * radius
		})
	end
end

local function gen_cricle_indices(ib, slices, baseidx)
	local last_idx = baseidx
	for i=1, slices do
		local next_idx = i == slices and baseidx or (last_idx + 1)					
		table.insert(ib, last_idx)
		table.insert(ib, next_idx)

		last_idx = next_idx
	end
end

function geometry.cone(slices, height, radius, needib, line)
	local function create_vb()
		if height and radius then			
			if slices < 3 then
				error(string.format("need at least 3 slices, %d given", slices))
				return 
			end

			local vb = {
				{0, height, 0},	-- top center
				{0, 0, 0}	-- bottom center
			}
			gen_cricle_vertices(vb, slices, 0, radius)
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
					table.insert(ib, topcenter_idx)
					table.insert(ib, bottomcenter_idx + i)

					-- bottom lines
					table.insert(ib, bottomcenter_idx)
					table.insert(ib, bottomcenter_idx + i)
				end	

				-- cricles lines
				gen_cricle_indices(ib, slices, bottomcenter_idx + 1)

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
				{0, half_height, 0},	-- top center
			}

			gen_cricle_vertices(vb, slices, half_height, radius)

			table.insert(vb, {0, -half_height, 0})	-- bottom center
			gen_cricle_vertices(vb, slices, -half_height, radius)
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
					table.insert(ib, topcenter_idx)
					table.insert(ib, topcenter_idx+i)

					-- body lines
					table.insert(ib, topcenter_idx+i)
					table.insert(ib, bottomcenter_idx+i)

					-- bottom lines
					table.insert(ib, bottomcenter_idx)
					table.insert(ib, bottomcenter_idx+i)
				end

				gen_cricle_indices(ib, slices, topcenter_idx+1)
				gen_cricle_indices(ib, slices, bottomcenter_idx+1)
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
		{0, radius, 0}, -- top
		{radius, 0, 0},
		{0, 0, -radius},
		{-radius, 0, 0},
		{0, 0, radius},
		{0, -radius, 0},	-- bottom
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
			return vb[i+1]
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
		local vbsize = #newvb
		table.insert(newvb, v0)
		table.insert(newvb, v1)
		table.insert(newvb, v2)

		table.insert(newvb, m0)
		table.insert(newvb, m1)
		table.insert(newvb, m2)

		local newindices = {
			0, 3, 5,
			1, 4, 3, 
			3, 4, 5,
			2, 5, 4,
		}

		for i=1, #newindices do
			newindices[i] = newindices[i] + vbsize
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

function geometry.sphereLatitude(slices, stacks, radius, needib, line)

end

function geometry.grid(width, height, unit)	
	local vb, ib = {}, {}		
	local function add_vertex(x, z, clr)
		table.insert(vb, {x, 0, z, clr})			
	end

	local w_len = width * unit
	local hw_len = w_len * 0.5

	local h_len = height * unit
	local hh_len = h_len * 0.5

	local color = 0x88c0c0c0

	local function add_line(x0, z0, x1, z1, color)
		add_vertex(x0, z0, color)
		add_vertex(x1, z1, color)
		-- call 2 times
		table.insert(ib, #ib)
		table.insert(ib, #ib)
	end

	-- center lines
	add_line(-hh_len, 0, hh_len, 0, 0x880000ff)		
	add_line(0, -hw_len, 0, hw_len, 0x88ff0000)		

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
	return vb, ib
end

return geometry