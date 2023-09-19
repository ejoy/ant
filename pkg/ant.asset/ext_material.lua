local serialize = import_package "ant.serialize"
local bgfx      = require "bgfx"
local async 	= require "async"
local fastio 	= serialize.fastio

local setting   = import_package "ant.settings"
local use_cluster_shading<const>	= setting:get "graphic/cluster_shading" ~= 0
local cs_skinning<const>			= setting:get "graphic/skinning/use_cs"

local matpkg	= import_package "ant.material"
local MA, matutil = matpkg.arena, matpkg.util
local sa		= require "system_attribs"

local function load(filename)
    return type(filename) == "string" and serialize.parse(filename, fastio.readall(filename)) or filename
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

local function update_attribs(attr, uniforms)
	local attrib, system, opt_mat_uniforms_samplers = attr.attrib, attr.system, {}
	if uniforms and #uniforms > 0 then
		for _, u in ipairs(uniforms) do
			local n = u.name
			local is_uniform, is_sampler, is_sa = n:find("u_") == 1, n:find("s_") == 1, sa.get(n)
			if (not is_sa) then 
				-- set handle to material's uniform and sampler attribs
				if is_uniform or is_sampler then
					attrib[n] = to_v(assert(attrib[n], u.handle))
					opt_mat_uniforms_samplers[n] = true
				end
			else 
				-- save system attribs from compiled shader file except existed system attribs
				system[#system+1] = n
			end
		end
	end
	-- some material's attribs(uniform and sampler with texture type) will be hidden by shader optizimation
		-- EX of uniform : u_pbr_factor
		-- EX of sampler : s_avg_luminance
	-- but material's buffer and sampler with image type should be saved
		-- EX of sampler : s_ssao_result
	for n, v in pairs(attrib) do
		local is_uniform, is_sampler = n:find("u_") == 1, n:find("s_") == 1
		if not opt_mat_uniforms_samplers[n] then
			if is_uniform or (is_sampler and v.texture) then
				attrib[n] = nil
			end
		end
	end
	return attrib, system
end

local function loader(filename)
    local material, attribute = async.material_create(filename)

    if material.state then
		material.state = bgfx.make_state(load(material.state))
    end

    if material.stencil then
        material.stencil = bgfx.make_stencil(load(material.stencil))
    end
    material.attrib, material.system = update_attribs(attribute, material.fx.uniforms)
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
