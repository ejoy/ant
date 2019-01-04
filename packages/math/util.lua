local math3d = require "math3d"
local ms = require "stack"

local util = {}
util.__index = util

function util.limit(v, min, max)
    if v > max then return max end
    if v < min then return min end
    return v
end

function util.equal(n0, n1)
    assert(type(n0) == "number")
    assert(type(n1) == "number")
    return util.iszero(n1 - n0)
end

function util.iszero(n, threshold)
    threshold = threshold or 0.00001
    return -threshold <= n and n <= threshold
end

local function create_persistent_type(persistent_type, v)
	local t = math3d.ref(persistent_type)
	ms(t, v, "=")
	return t
end

local function to_v(math_id)
	return ms(math_id, "m")
end

function util.srt(s, r, t, ispersistent)
	local srt = {type="srt", s=s, r=r, t=t}
	if ispersistent then
		return create_persistent_type("matrix", srt)
	end

	return ms(srt, "P")
end

function util.srt_from_entity(entity)
	return util.srt(entity.scale, entity.rotation, entity.position)
end

function util.srt_v(s, r, t, ispersistent)
	return to_v(util.srt(s, r, t, ispersistent))
end

function util.proj(frustum, ispersistent)
	if ispersistent then
		return create_persistent_type("matrix", frustum)
	end
	return ms(frustum, "P")
end

function util.proj_v(frustum, ispersistent)
	return to_v(util.proj(frustum, ispersistent))
end

function util.degree_to_radian(angle)
	return (angle / 180) * math.pi
end

function util.radian_to_degree(radian)
	return (radian / math.pi) * 180
end

function util.frustum_from_fov(frustum, n, f, fov, aspect)
	local hh = math.tan(util.degree_to_radian(fov * 0.5)) * n
	local hw = aspect * hh
	frustum.n = n
	frustum.f = f
	frustum.l = -hw
	frustum.r = hw
	frustum.t = hh
	frustum.b = -hh
end

function util.create_persistent_vector(value)
	local v = math3d.ref "vector"
	ms(v, value, "=")
	return v
end

function util.create_persistent_matrix(value)
	local m = math3d.ref "matrix"
	ms(m, value, "=")
	return m
end

function util.identify_transform(entity)
	ms(	entity.scale, {1, 1, 1, 0}, "=",
	entity.rotation, {0, 0, 0, 0}, "=",
	entity.position, {0, 0, 0, 1}, "=")
end

function util.print_srt(e, numtab)
	local tab = ""
	if numtab then
		for i=1, numtab do
			tab = tab .. '\t'
		end		
	end
	
	local s_str = tostring(e.scale)
	local r_str = tostring(e.rotation)
	local t_str = tostring(e.position)

	print(tab .. "scale : ", s_str)
	print(tab .. "rotation : ", r_str)
	print(tab .. "position : ", t_str)
end

local function update_frustum_from_aspect(rt, frustum)
	local aspect = rt.w / rt.h
	local tmp_h = frustum.t - frustum.b
	local tmp_hw = aspect * tmp_h * 0.5
	frustum.l = -tmp_hw
	frustum.r = tmp_hw
end

function util.view_proj_matrix(camera_entity)	
	local view = ms(camera_entity.position, camera_entity.rotation, "dLP")
	local vr = camera_entity.view_rect
	local frustum = assert(camera_entity.frustum)
	update_frustum_from_aspect(vr, frustum)
	
	return view, util.proj(frustum)
end

local function math3d_value_save(v, arg)
	assert(type(v) == "userdata")	
	local t = ms(v, "T")
	assert(type(t) == "table" and t.type ~= nil)
	return t
end

local function get_math3d_value_load(typename)
	return function(s, arg)
		if s.type == nil then
			error "vector load function invalid format"
		end

		if s.type ~= 1 and s.type ~= 2 then
			error "vector load function need vector type"
		end

		local math3d = require "math3d"
		local v = math3d.ref(typename)		
		ms(v, s, "=")
		return v
	end
end

local function create_component_elem(tt)
	return { 
		type = "userdata",
		default = function() return math3d.ref(tt) end,
		save = math3d_value_save,
		load = get_math3d_value_load(tt), 
	}
end

function util.create_component_vector()
	return create_component_elem("vector")
end

function util.create_component_matrix()
	return create_component_elem("matrix")
end

return util