local draw = {}; draw.__index = {}

local geo = require "editor.ecs.render.geometry"
local ms = require "math.stack"

local function gen_color_vertex(pt, color, transform)
	assert(#pt == 3)
	local npt = ms(transform, {pt[1], pt[2], pt[3], 1}, "*T")
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

local function offset_index_buffer(ib, istart, iend, offset)	
	for i=istart, iend do
		ib[i] = offset + ib[i]
	end	
end

local function create_bone(ratio)
	local vb, ib = geo.cone(4, ratio, 0.25, true, true)
	local vbdown, ibdown = geo.cone(4, -(1-ratio), 0.25, true, true)
	offset_index_buffer(ibdown, 1, #ibdown, #vb)
	
	append_array(vbdown, vb)
	append_array(ibdown, ib)
	return vb, ib
end

function draw.draw_bones(joints, color, transform, desc)
	local dvb = desc.vb
	local dib = desc.ib
	local updown_ratio = 0.3

	local bones = {}
	local numjoints = #joints
	for i=1, numjoints do
		if not joints:isroot(i) then
			table.insert(bones, {joints:parent(i), i})
		end
	end

	local bonevb, boneib = create_bone(updown_ratio)
	local localtrans = ms({type="srt", r={-90, 0, 0}, t={0, 0, updown_ratio}}, "P")

	local function print_bone(bone)
		local begidx, endidx = bone[1], bone[2]
		local jbeg, jend = joints[begidx], joints[endidx]
		print(string.format("begin joint:%d %s", begidx, jbeg.name))
		print(string.format("end joint:%d %s", endidx, jend.name))
		print(string.format("begin joint:\n\ts:(%2f, %2f, %2f)\n\tr:(%2f, %2f, %2f, %2f)\n\tt(%2f, %2f, %2f)", 
			jbeg.s[1], jbeg.s[2], jbeg.s[3],
			jbeg.r[1], jbeg.r[2], jbeg.r[3], jbeg.r[4],
			jbeg.t[1], jbeg.t[2], jbeg.t[3]))

		print(string.format("end joint:\n\ts:(%2f, %2f, %2f)\n\tr:(%2f, %2f, %2f, %2f)\n\tt(%2f, %2f, %2f)", 
			jend.s[1], jend.s[2], jend.s[3],
			jend.r[1], jend.r[2], jend.r[3], jend.r[4],
			jend.t[1], jend.t[2], jend.t[3]))
	end

	local function get_world_pos(idx)
		local indices = {}
		while not joints:isroot(idx) do
			table.insert(indices, idx)
			idx = joints:parent(idx)
		end

		assert(joints:isroot(idx))
		table.insert(indices, idx)

		local function get_srt(i)
			local ii = indices[i]
			local j = joints[ii]
			local e = ms({type="q", table.unpack(j.r)}, "eP")
			return ms({type="srt", s=j.s, r=e, t=j.t}, "P")
		end

		local num_indices = #indices	
		local srt = get_srt(num_indices)
		for i=num_indices-1, 1, -1 do
			local csrt = get_srt(i)
			srt = ms(srt, csrt, "*P")
		end
		return ms(srt, {0, 0, 0, 1}, "*T")
	end

	for _, b in ipairs(bones) do		
		local beg_pos, end_pos = get_world_pos(b[1]), get_world_pos(b[2])
		
		print_bone(b)
		
		local vec = ms(end_pos, beg_pos, "-P")
		local len = math.sqrt(ms(vec, vec, ".T")[1])
		local rotation = ms(vec, "neP")
		
		local finaltrans = ms({type="srt", r=rotation, s={len, len, len}, t=beg_pos}, localtrans, "*P")
		if transform then
			finaltrans = ms(transform, finaltrans, "*P")
		end

		local vstart = #dvb
		append_array(bonevb, dvb)
		local istart = #dib+1
		append_array(boneib, dib)
		if vstart ~= 0 then
			offset_index_buffer(dib, istart, #dib, vstart)			
		end
		
		for i=vstart+1, #dvb do
			local v = dvb[i]
			local nv = ms(finaltrans, {v[1], v[2], v[3], 1}, "*T")
			nv[4] = color
			dvb[i] = nv
		end	
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