local draw = {}; draw.__index = {}

local geo = require "editor.ecs.render.geometry"
local ms = require "math.stack"

local function gen_color_vertex(pt, color, transform)
	assert(#pt == 3)
	local npt = ms({pt[1], pt[2], pt[3], 1}, transform, "*T")
	npt[4] = color
	return npt
end

local function gen_color_vertices(pts, color, transform, vb)
	local vnum = #pts
	if transform then
		for i=1, vnum do
			table.insert(vb, gen_color_vertex(pts[i], color, transform))
		end
	else
		for i=1, vnum do
			local pt = pts[i]
			table.insert(vb, {pt[1], pt[2], pt[3], color})
		end
	end
end

local function add_primitive(primitives, voffset, vnum, ioffset, inum)
	table.insert(primitives, {startVertex=voffset, numVertices=vnum, startIndex=ioffset, numIndices=inum})
end

local function append_array(from, to)
	table.move(from, 1, #from, #to+1, to)
end

local function create_bone(bone, color, transform, ratio)
	local vb, ib = {}, {}
	local vbup, ibup = geo.cone(4, ratio, ratio, true, true)
	local vbdown, ibdown = geo.cone(4, -(1 - ratio), ratio, true, true)

	append_array(vbup, vb)
	append_array(vbdown, vb)

	append_array(ibup, ib)
	append_array(ibdown, ib)

	local function bone_transform(b)
		local r = ms(b.r, "eP")
		return ms({type="srt", r=r, s=b.s, t=b.t}, "P")
	end

	local bonetrans = bone_transform(bone)
	local trans = ms({type="srt", r={180, 0, 0}, t={0, 0.3, 0}}, "P")
	local finaltrans = ms(transform, bonetrans, trans, "**P")
	for i=1, #vb do
		local v = vb[i]
		local nv = ms({v[1], v[2], v[3], 1}, finaltrans, "T")
		nv[4] = color
		vb[i] = nv
	end
end

function draw.draw_bones(bones, color, transform, desc)
	local dvb = desc.vb
	local dib = desc.ib
	local updown_ratio = 0.3
	for _, b in ipairs(bones) do
		local vb, ib = create_bone(b, color, transform, updown_ratio)
		
		append_array(vb, dvb)
		append_array(ib, dib)
	end
end

function draw.draw_line(pts, color, transform, desc)
	local vb = assert(desc.vb)

	local offset = #vb
	local num = #pts
	gen_color_vertices(pts, color, transform, vb)
	add_primitive(desc.primitives, offset, num)
end

local function draw_primitve(color, transform, desc, buffer_generator)
	--local vb, ib = geo.sphere(1, sphere.radius, true, true)
	local vb, ib = buffer_generator()

	local desc_vb = assert(desc.vb)
	local offset = #desc_vb
	gen_color_vertices(vb, color, transform, desc_vb)
	local desc_ib = assert(desc.ib)
	local ioffset = #desc_ib
	append_array(ib, desc_ib)
	add_primitive(desc.primitives, offset, #vb, ioffset, #ib)
end

function draw.draw_cone(cone, color, transform, desc)
	draw_primitve(color, transform, desc, 
	function()
		return geo.cone(cone.slices, cone.height, cone.radius, true, true)
	end)
end

function draw.draw_sphere(sphere, color, transform, desc)
	draw_primitve(color, transform, desc, function()
		return geo.sphere(sphere.tessellation, sphere.radius, true, true)
	end)
end

return draw