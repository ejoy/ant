local draw = {}; draw.__index = {}

local math3d = import_package "ant.math"
local ms = math3d.stack

local geo = require "geometry"

local function gen_color_vertex(pt, color, transform)
	local npt = ms(transform, {pt[1], pt[2], pt[3], 1}, "*T")
	npt[4] = color
	return npt
end

local function gen_color_vertices(pts, color, transform, vb)
	local vnum = #pts
	if transform then
		for i=1, vnum do
			local v = gen_color_vertex(pts[i], color, transform)
			
			table.move(v, 1, #v, #vb+1, vb)
		end
	else
		for i=1, vnum do			
			table.move(pts[i], 1, 3, #vb+1, vb)
			vb[#vb+1] = color
		end
	end
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
	local radius = 0.25
	local vb = {
		{0, ratio, 0},
		{-radius, 0, -radius},
		{radius, 0, -radius},
		{radius, 0, radius},
		{-radius, 0, radius},
		{0, -(1-ratio), 0},
	}

	local ib = {
		0, 1, 0, 2, 0, 3, 0, 4,
		1, 2, 2, 3, 3, 4, 4, 1,

		1, 3, 2, 4,

		5, 1, 5, 2, 5, 3, 5, 4,
	}
	return vb, ib
end

-- local function print_bone(bone)
-- 	local begidx, endidx = bone[1], bone[2]
-- 	local jbeg, jend = joints[begidx], joints[endidx]
-- 	print(string.format("begin joint:%d %s", begidx, jbeg.name))
-- 	print(string.format("end joint:%d %s", endidx, jend.name))
-- 	print(string.format("begin joint:\n\ts:(%2f, %2f, %2f)\n\tr:(%2f, %2f, %2f, %2f)\n\tt(%2f, %2f, %2f)", 
-- 		jbeg.s[1], jbeg.s[2], jbeg.s[3],
-- 		jbeg.r[1], jbeg.r[2], jbeg.r[3], jbeg.r[4],
-- 		jbeg.t[1], jbeg.t[2], jbeg.t[3]))

-- 	print(string.format("end joint:\n\ts:(%2f, %2f, %2f)\n\tr:(%2f, %2f, %2f, %2f)\n\tt(%2f, %2f, %2f)", 
-- 		jend.s[1], jend.s[2], jend.s[3],
-- 		jend.r[1], jend.r[2], jend.r[3], jend.r[4],
-- 		jend.t[1], jend.t[2], jend.t[3]))
-- end

local function generate_bones(ske)	
	local bones = {}
	for i=1, #ske do
		if not ske:isroot(i) then
			table.insert(bones, {ske:parent(i), i})
		end
	end
	return bones
end

function draw.draw_skeleton(ske, ani, color, transform, desc)	
	local hie_util = import_package "ant.scene".hierarchy
	
	local bones = generate_bones(ske)

	local joints = ani and ani:joints() or hie_util.generate_joints_worldpos(ske)
	return draw.draw_bones(bones, joints, color, transform, desc)
end

function draw.draw_bones(bones, joints, color, transform, desc)
	local dvb = desc.vb
	local dib = desc.ib
	local updown_ratio = 0.3

	local bonevb, boneib = create_bone(updown_ratio)
	--local localtrans = ms({type="srt", r={-90, 0, 0}, t={0, 0, updown_ratio}}, "P")
	local localtrans = ms:srtmat({1}, ms:euler2quat{math.rad(-90), 0, 0}, {0, 0, updown_ratio, 1})

	local poitions = {}
	local origin = ms({0 ,0, 0, 1}, "P")
	for _, j in ipairs(joints) do
		local p = ms(ms:matrix(j), origin, "*P")	-- extract poistion
		table.insert(poitions, p)
	end

	--for _, b in ipairs(bones) do
	for i=1, #bones do
		local b = bones[i]
		local beg_pos, end_pos = poitions[b[1]], poitions[b[2]]
		local vec = ms(end_pos, beg_pos, "-P")
		local len = ms:length(vec)
		local rotation = ms(vec, "nDP")
		
		local finaltrans = ms({type="srt", r=rotation, s={len, len, len}, t=beg_pos}, localtrans, "*P")
		if transform then
			finaltrans = ms(transform, finaltrans, "*P")
		end

		local vstart = (#dvb - 1) // 4

		for _, bb in ipairs(bonevb) do
			local newbb = {bb[1], bb[2], bb[3], 1}
			local t = ms(finaltrans, newbb, "*T")
			t[4] = color
			append_array(t, dvb)
		end

		local istart = #dib+1
		append_array(boneib, dib)
		if vstart ~= 0 then
			offset_index_buffer(dib, istart, #dib, vstart)
		end
	end
end

function draw.draw_line(pts, color, transform, desc)
	local vb = assert(desc.vb)
	gen_color_vertices(pts, color, transform, vb)

	local ib = assert(desc.ib)
	for i=1, #pts do
		ib[i] = i-1
	end
end

local function draw_primitve(color, transform, desc, buffer_generator)
	--local vb, ib = geo.sphere(1, sphere.radius, true, true)
	local vb, ib = buffer_generator()

	local desc_vb = assert(desc.vb)	
	gen_color_vertices(vb, color, transform, desc_vb)
	local desc_ib = assert(desc.ib)	
	append_array(ib, desc_ib)
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

function draw.draw_capsule(capsule, color, transform, desc)
	draw_primitve(color, transform, desc, function()
		return geo.capsule(capsule.radius, capsule.height, capsule.tessellation, true, true)
	end)
end

function draw.draw_aabb_box(aabb, color, transform, desc)
	draw_primitve(color, transform, desc, function()
		return geo.box_from_aabb(aabb, true, true)
	end)
end

function draw.draw_box(size, color, transform, desc)
	draw_primitve(color, transform, desc, function ()
		return geo.box(size, true, true)
	end)
end

function draw.draw_frustum(frustum, color, transform, desc)

end

return draw