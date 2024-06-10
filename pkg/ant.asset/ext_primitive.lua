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
		-- top            x   y   z  u  v
		-0.5,  0.5,  0.5, 0,  1,  0, 0, 0,
		 0.5,  0.5,  0.5, 0,  1,  0, 1, 0,
		-0.5,  0.5, -0.5, 0,  1,  0, 0, 1,
		 0.5,  0.5, -0.5, 0,  1,  0, 1, 1,
		-- bottom
		-0.5, -0.5,  0.5, 0, -1,  0, 0, 0,
		 0.5, -0.5,  0.5, 0, -1,  0, 1, 0,
		-0.5, -0.5, -0.5, 0, -1,  0, 0, 1,
		 0.5, -0.5, -0.5, 0, -1,  0, 1, 1,
		 -- front
		-0.5,  0.5, -0.5, 0,  0, -1, 0, 0,
		 0.5,  0.5, -0.5, 0,  0, -1, 1, 0,
		-0.5, -0.5, -0.5, 0,  0, -1, 0, 1,
		 0.5, -0.5, -0.5, 0,  0, -1, 1, 1,
		 -- back
		-0.5,  0.5,  0.5, 0,  0,  1, 0, 0,
		 0.5,  0.5,  0.5, 0,  0,  1, 1, 0,
		-0.5, -0.5,  0.5, 0,  0,  1, 0, 1,
		 0.5, -0.5,  0.5, 0,  0,  1, 1, 1,
		 -- left
	    -0.5, -0.5,  0.5, -1,  0, 0, 0, 0,
		-0.5,  0.5,  0.5, -1,  0, 0, 1, 0,
		-0.5, -0.5, -0.5, -1,  0, 0, 0, 1,
		-0.5,  0.5, -0.5, -1,  0, 0, 1, 1,
		-- right
	     0.5, -0.5,  0.5,  1,  0, 0, 0, 0,
		 0.5,  0.5,  0.5,  1,  0, 0, 1, 0,
		 0.5, -0.5, -0.5,  1,  0, 0, 0, 1,
		 0.5,  0.5, -0.5,  1,  0, 0, 1, 1,
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
	return create_mesh({"p3|n3|t2", vb}, cube_ib, aabb)
end

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
