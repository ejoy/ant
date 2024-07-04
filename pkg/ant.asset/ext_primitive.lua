local renderpkg	= import_package "ant.render"
local layoutmgr = renderpkg.layoutmgr
local ext_meshbin 	= require "ext_meshbin"

local bgfx = require "bgfx"

local function create_mesh(vbdata, ibdata, aabb)
	local vb = {
		start = 0,
	}
	local mesh = {vb = vb}

	if aabb then
		mesh.bounding = {aabb=aabb}
	end
	
	local correct_layout = layoutmgr.correct_layout(vbdata[1])
	local flag = layoutmgr.vertex_desc_str(correct_layout)

	vb.num = #vbdata[2] // #flag
	vb.declname = correct_layout
	vb.memory = {flag, vbdata[2]}

	if ibdata then
		mesh.ib = {
			start = 0, num = #ibdata,
			memory = {"w", ibdata},
		}
	end
	return ext_meshbin.init(mesh)
end

local primitive = {}

function primitive.plane(u0, v0, u1, v1)
	if not u0 then
		u0, v0, u1, v1 = 0, 0, 1, 1
	end
	local vb = {
		-0.5, 0, 0.5, 0, 1, 0, u0, v0,	--left top
		 0.5, 0, 0.5, 0, 1, 0, u1, v0,	--right top
		-0.5, 0,-0.5, 0, 1, 0, u0, v1,	--left bottom
		 0.5, 0,-0.5, 0, 1, 0, u1, v1,	--right bottom
	}
	return create_mesh({"p3|n3|t2", vb}, {0, 1, 2, 1, 3, 2}, {{-0.5, 0, -0.5}, {0.5, 0, 0.5}})
end

function primitive.quad()
	local u0, v0, u1, v1 = 0, 0, 1, 1
	local vb = {
		-0.5, 1, 0, 0, 0, 1, u0, v0,	--left top
		 0.5, 1, 0, 0, 0, 1, u1, v0,	--right top
		-0.5, 0, 0, 0, 0, 1, u0, v1,	--left bottom
		 0.5, 0, 0, 0, 0, 1, u1, v1,	--right bottom
	}
	return create_mesh({"p3|n3|t2", vb}, {0, 1, 2, 1, 3, 2}, {{-0.5, 0, 0}, {0.5, 1, 0, 0}})
end

local cube_ib = {
	 0,  1,  2,
	 1,  3,  2,

	 4,  6,  5,
	 5,  6,  7,


	 8,  9,  10,
	 9,  11, 10,

	12,  14, 13,
	13,  14, 15,

	16,  17, 18,
	17,  19, 18,

	20,  22, 21,
	21,  22, 23,
}

function primitive.cube(size)
	local vb = {
		-- top            x   y   z
		-0.5,  0.5,  0.5, 0,  1,  0,
		 0.5,  0.5,  0.5, 0,  1,  0,
		-0.5,  0.5, -0.5, 0,  1,  0,
		 0.5,  0.5, -0.5, 0,  1,  0,
		-- bottom
		-0.5, -0.5,  0.5, 0, -1,  0,
		 0.5, -0.5,  0.5, 0, -1,  0,
		-0.5, -0.5, -0.5, 0, -1,  0,
		 0.5, -0.5, -0.5, 0, -1,  0,
		 -- front
		-0.5,  0.5, -0.5, 0,  0, -1,
		 0.5,  0.5, -0.5, 0,  0, -1,
		-0.5, -0.5, -0.5, 0,  0, -1,
		 0.5, -0.5, -0.5, 0,  0, -1,
		 -- back
		-0.5,  0.5,  0.5, 0,  0,  1,
		 0.5,  0.5,  0.5, 0,  0,  1,
		-0.5, -0.5,  0.5, 0,  0,  1,
		 0.5, -0.5,  0.5, 0,  0,  1,
		 -- left
	    -0.5, -0.5,  0.5, -1,  0, 0,
		-0.5,  0.5,  0.5, -1,  0, 0,
		-0.5, -0.5, -0.5, -1,  0, 0,
		-0.5,  0.5, -0.5, -1,  0, 0,
		-- right
	     0.5, -0.5,  0.5,  1,  0, 0,
		 0.5,  0.5,  0.5,  1,  0, 0,
		 0.5, -0.5, -0.5,  1,  0, 0,
		 0.5,  0.5, -0.5,  1,  0, 0,
	}

	local aabb = {
		{-0.5, -0.5, -0.5},
		{0.5, 0.5, 0.5},
	}
	if size then
		for i = 1, #vb, 6 do
			vb[i] = vb[i] * size
			vb[i+1] = vb[i+1] * size
			vb[i+2] = vb[i+2] * size
		end
		for _, vec in ipairs(aabb) do
			for k,v in ipairs(vec) do
				vec[k] = v * size
			end
		end
	end
	return create_mesh({"p3|n3", vb}, cube_ib, aabb)
end

-- todo : need rework
--forward to z-axis, as 1 size
function primitive:arrow(headratio, arrowlen, coneradius, cylinderradius)
	arrowlen = arrowlen or 1
	headratio = headratio or 0.15
	local headlen<const> = arrowlen * (1.0-headratio)
	local fmt<const> = "fff"
	local layout<const> = layoutmgr.get "p3"

	coneradius	= coneradius or 0.1
	cylinderradius	= cylinderradius or coneradius * 0.5
	local slicenum<const> 		= 10
	local deltaradian<const> 	= math.pi*2/slicenum

	local numv<const>			= slicenum*3+3	--3 center points
	local vb = bgfx.memory_buffer(layout.stride*numv)
	local function add_v(idx, x, y, z)
		local vboffset = layout.stride*idx+1
		vb[vboffset] = fmt:pack(x, y, z-arrowlen)
	end

	add_v(0,0.0, 0.0, arrowlen)
	add_v(1,0.0, 0.0, headlen)
	add_v(2,0.0, 0.0, 0.0)

	local offset=3

	for i=0, slicenum-1 do
		local r = deltaradian*i
		local c, s = math.cos(r), math.sin(r)
		local idx = i+offset
		add_v(idx,	c*coneradius, s*coneradius, headlen)

		local idx1 = idx+slicenum
		add_v(idx1,	c*cylinderradius, s*cylinderradius, headlen)
		
		local idx2 = idx1+slicenum
		add_v(idx2, c*cylinderradius, s*cylinderradius, 0.0)
	end

	local numtri<const>		= slicenum*5	--3 circle + 1 quad
	local ibstride<const>	= 2
	local numi<const>		= numtri*3
	local ib = bgfx.memory_buffer(ibstride*numtri*3)
	local ibfmt<const> = "HHH"
	local iboffset = 1
	local function add_t(i0, i1, i2)
		ib[iboffset] = ibfmt:pack(i0, i1, i2)
		iboffset = iboffset + ibstride*3
	end

	local ic1, ic2, ic3 = 0, 1, 2
	local cc1 = ic3+1
	local cc2 = cc1+slicenum
	local cc3 = cc2+slicenum

	--
	for i=0, slicenum-1 do
		--cone
		do
			local i2, i3 = cc1+i, cc1+i+1
			if i == slicenum-1 then
				i3 = cc1
			end
			add_t(ic1, i2, i3)
			add_t(ic2, i3, i2)
		end

		do
			--cylinder quad
			local v0 = cc2+i
			local v1 = cc3+i
			local v2 = v1+1
			local v3 = v0+1

			if i == slicenum-1 then
				v2 = cc3
				v3 = cc2
			end
			
			add_t(v0, v1, v2)
			add_t(v2, v3, v0)

			add_t(ic3, v2, v1)
		end
	end
	return {
		vb = {
			start = 0,
			num = numv,
			declname = "p3",
			handle = bgfx.create_vertex_buffer(vb, layout.handle),
		},
		ib = {
			start = 0,
			num = numi,
			handle = bgfx.create_index_buffer(ib),
		}
	}
end

function primitive.sphere(triangles)
	triangles = triangles or 1480
	local t = (1 + math.sqrt(5)) / 2
	local points = {}
	local faces = {}

	-- add vertex to mesh, fix position to be on unit sphere
	local function add_point(x, y, z)
		local length = math.sqrt(x * x + y * y + z * z)
		local v = 1 / length
		points[#points + 1] = {x * v, y * v, z * v}
	end

	-- add triangle to mesh
	local function add_triangle(p1, p2, p3, in_faces)
		local list = in_faces or faces
		list[#list + 1] = {p1, p2, p3}
	end

	-- create 12 vertices of a icosahedron
	add_point(-1, t, 0)
	add_point(1, t, 0)
	add_point(-1, -t, 0)
	add_point(1, -t, 0)

	add_point(0, -1, t)
	add_point(0, 1, t)
	add_point(0, -1, -t) 
	add_point(0, 1, -t)

	add_point(t, 0, -1)
	add_point(t, 0, 1)
	add_point(-t, 0, -1)
	add_point(-t, 0, 1)

	-- create 20 triangles of the icosahedron
	add_triangle(0, 11, 5)
	add_triangle(0, 5, 1)
	add_triangle(0, 1, 7)
	add_triangle(0, 7, 10)
	add_triangle(0, 10, 11)
	add_triangle(1, 5, 9)
	add_triangle(5, 11, 4)
	add_triangle(11, 10, 2)
	add_triangle(10, 7, 6)
	add_triangle(7, 1, 8)
	add_triangle(3, 9, 4)
	add_triangle(3, 4, 2)
	add_triangle(3, 2, 6)
	add_triangle(3, 6, 8)
	add_triangle(3, 8, 9)
	add_triangle(4, 9, 5)
	add_triangle(2, 4, 11)
	add_triangle(6, 2, 10)
	add_triangle(8, 6, 7)
	add_triangle(9, 8, 1)

	-- return index of point in the middle of p1 and p2
	local function get_middle_point(idx1, idx2)
		local p1 = points[idx1 + 1]
		local p2 = points[idx2 + 1]
		local middle = {(p1[1] + p2[1]) * 0.5, (p1[2] + p2[2]) * 0.5, (p1[3] + p2[3]) * 0.5}
		add_point(middle[1], middle[2], middle[3])
		return #points - 1;
	end

	-- refine triangles
	while #faces < triangles do 
		local faces2 = {}
		for _, f in ipairs(faces) do 
			local a = get_middle_point(f[1], f[2])
			local b = get_middle_point(f[2], f[3])
			local c = get_middle_point(f[3], f[1])
			add_triangle(f[1], a, c, faces2)
			add_triangle(f[2], b, a, faces2)
			add_triangle(f[3], c, b, faces2)
			add_triangle(a, b, c, faces2)
		end
		faces = faces2
	end

	local vb = {}
	for _, p in ipairs(points) do 
		local index = #vb
		-- POSITION
		vb[index + 1] = p[1]
		vb[index + 2] = p[2]
		vb[index + 3] = p[3]

		-- NORMAL
		vb[index + 4] = p[1]
		vb[index + 5] = p[2]
		vb[index + 6] = p[3]
	end
	local vbdata = {"p3|n3", vb}
	local ibdata = {}
	for _, f in ipairs(faces) do 
		local index = #ibdata
		ibdata[index + 1] = f[1]
		ibdata[index + 2] = f[2]
		ibdata[index + 3] = f[3]
	end
	local aabb = {{-1, -1, 1}, {1, 1, 1}}
	return create_mesh(vbdata, ibdata, aabb)
end

local function loader(fullname)
	local name = fullname:match "(.+)%.primitive$"
	local create = primitive[name]
	if create then
		return create()
	end
	local name, args = name:match "(.+)(%b())$"
	create = primitive[name] or error ("No primitive type : " .. fullname)
	local t = {}
	local n = 1
	for v in args:sub(2,-2):gmatch "[^,]+" do
		t[n] = tonumber(v) or v
		n = n + 1			
	end
	
	return create(table.unpack(t))
end

return {
	loader = loader,
	unloader = ext_meshbin.delete,
}
