local serialize = import_package "ant.serialize"
local bgfx      = require "bgfx"
local async 	= require "async"
local fs 	    = require "filesystem"

local setting   = import_package "ant.settings".setting
local use_cluster_shading<const>	= setting:get "graphic/cluster_shading" ~= 0
local cs_skinning<const>			= setting:get "graphic/skinning/use_cs"

local matpkg	= import_package "ant.material"
local MA, matutil = matpkg.arena, matpkg.util
local sa		= require "system_attribs"

local function readall(filename)
    local f <close> = assert(fs.open(fs.path(filename), "rb"))
    return f:read "a"
end

local function load(filename)
    return type(filename) == "string" and serialize.parse(filename, readall(filename)) or filename
end

local function is_vec(v) return #v == 4 end

local function to_math_v(v)
	local T = type(v[1])
	if T == 'number' then
		if is_vec(v) then
			return matutil.tv4(v), "v1"
		end
		return matutil.tm4(v), "m1"
	end

	if T == 'table' then
		assert(type(v[1]) == 'table')
		local function from_array(array, op)
			local t = {}
			for _, a in ipairs(array) do
				t[#t+1] = op(a)
			end
			return table.concat(t)
		end

		if is_vec(v[1]) then
			return from_array(v, matutil.tv4), "v" .. #v
		end
		return from_array(v, matutil.tm4), "m" .. #v
	end

	error "Invalid property"
end

local function to_v(t, h)
	assert(type(t) == "table")
	if t.stage then
		t.handle = h
		return t
	end

	local v = {handle=h}
	assert(not t.index, "not support color palette")

	v.type = 'u'
	v.value, v.utype = to_math_v(t)
	return v
end

local DEF_PROPERTIES<const> = {}

local function generate_properties(fx, properties)
	local uniforms = fx.uniforms
	local new_properties = {}
	properties = properties or DEF_PROPERTIES
	if uniforms and #uniforms > 0 then
		for _, u in ipairs(uniforms) do
			local n = u.name
			if not n:match "@data" then
				local v
				if "s_lightmap" == n then
					v = {stage = 8, handle = u.handle, value = nil, type = 't'}
				else
					local pv = properties[n] or {0.0, 0.0, 0.0, 0.0}
					v = to_v(pv, u.handle)
				end

				new_properties[n] = v
			end
		end
	end

	for k, v in pairs(properties) do
		if new_properties[k] == nil then
			if v.image or v.buffer then
				assert(v.access and v.stage)
				if v.image then
					assert(v.mip)
				end
				new_properties[k] = v
			end
		end
	end

	
	if fx.shader_type == "COMPUTE" then
		return {}, new_properties
	end

	local system, attrib = {}, {}
	for k, p in pairs(new_properties) do
		if sa[k] then
			system[#system+1] = k
		else
			attrib[k] = p
		end
	end

	local setting = fx.setting
	if setting.lighting == "on" then
		system[#system+1] = "b_light_info"
		if use_cluster_shading then
			system[#system+1] = "b_light_grids"
			system[#system+1] = "b_light_index_lists"
		end
	end
	if cs_skinning and setting.skinning == "on" then
		attrib["b_skinning_matrices_vb"].type	= 'b'
		attrib["b_skinning_in_dynamic_vb"].type	= 'b'
		attrib["b_skinning_out_dynamic_vb"].type= 'b'
	end
	return system, attrib
end

local function loader(filename)
    local material = async.material_create(filename)

    if material.state then
		material.state = bgfx.make_state(load(material.state))
    end

    if material.stencil then
        material.stencil = bgfx.make_stencil(load(material.stencil))
    end
    material.system, material.attrib = generate_properties(material.fx, material.properties)
    material.object = MA.material_load(filename, material.state, material.stencil, material.fx.prog, material.system, material.attrib)
    return material
end

local function unloader(m)
	m.object:release()
	m.object = nil

	local function destroy_handle(fx, n)
		local h = fx[n]
		if h then
			bgfx.destroy(h)
			fx[n] = nil
		end
	end
	
	-- local fx = m.fx
	-- assert(fx.prog)
	-- destroy_handle(fx, "prog")

	-- destroy_handle(fx, "vs")
	-- destroy_handle(fx, "fs")
	-- destroy_handle(fx, "cs")
end

return {
    loader = loader,
    unloader = unloader,
}
