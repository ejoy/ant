local cr        = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"
local assetmgr  = require "asset"
local bgfx      = require "bgfx"
local math3d    = require "math3d"
local sd        = import_package "ant.settings".setting
local use_cluster_shading = sd:data().graphic.cluster_shading ~= 0
local matobj	= require "matobj"
local load_fx 	= require "load_fx"
local respath 	= require "respath"
local fs 	    = require "filesystem"

local function readall(filename)
    local f <close> = assert(fs.open(fs.path(filename), "rb"))
    return f:read "a"
end

local function load(filename)
    return type(filename) == "string" and serialize.parse(filename, readall(filename)) or filename
end

local function to_math_v(v)
	return #v == 4 and math3d.vector(v) or math3d.matrix(v)
end

local function to_v(t, h)
	assert(type(t) == "table")
	if t.stage then
		t.handle = h
		return t
	end

	local v = {handle=h}
	if t.index then
		v.type = 'p'
		local n = t.palette
		local cp_idx = matobj.color_palettes[n]
		if cp_idx == nil then
			error(("Invalid color palette:%s"):format(n))
		end

		v.value = {pal=cp_idx, color=t.index}
		return v
	end

	v.type = 'u'
	if type(t[1]) == "number" then
		v.value = to_math_v(t)
	else
		local res = {}
		for i, v in ipairs(t) do
			res[i] = to_math_v(v)
		end
		v.value = res
	end
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

	local setting = fx.setting
	if setting.lighting == "on" then
		new_properties["b_light_info"] = {type = 'b'}
		if use_cluster_shading then
			new_properties["b_light_grids"] = {type='b'}
			new_properties["b_light_index_lists"] = {type='b'}
		end
	end
	if setting.skinning == "on" then
		new_properties["b_skinning_matrices_vb"].type = 'b'
		new_properties["b_skinning_in_dynamic_vb"].type = 'b'
		new_properties["b_skinning_out_dynamic_vb"].type = 'b'
	end
	return new_properties
end

local function loader(filename)
    local material = load_fx(filename)

    if material.state then
		material.state = bgfx.make_state(load(material.state))
    end

    if material.stencil then
        material.stencil = bgfx.make_stencil(load(material.stencil))
    end
    if material.properties then
        for _, v in pairs(material.properties) do
            if v.texture then
                v.type = 't'
                v.value = assetmgr.resource(v.texture).id
			elseif v.image then
                v.type = 'i'
                v.value = assetmgr.resource(v.image).id
			elseif v.buffer then
				v.type = 'b'
            end
        end
    end

    material.properties = generate_properties(material.fx, material.properties)
    material.object = matobj.rmat.material(material.state, material.stencil, material.properties, material.fx.prog)
    return material
end

local function unloader()
end

return {
    loader = loader,
    unloader = unloader,
}
