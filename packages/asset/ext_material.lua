local cr        = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"
local assetmgr  = require "asset"
local bgfx      = require "bgfx"
local math3d    = require "math3d"
local sd        = import_package "ant.settings".setting
local use_cluster_shading = sd:data().graphic.cluster_shading ~= 0

local CMATOBJ   = require "cmatobj"
local rmat      = require "render.material"

local function load(filename)
    return type(filename) == "string" and serialize.parse(filename, cr.read_file(filename)) or filename
end

local function to_t(t, handle)
	local v = {stage=assert(t.stage), handle=handle}
	if t.texture then
		v.value = t.texture.handle
		v.type = 't'
	elseif t.image then
		v.value = t.image.handle
		v.mip = t.mip
		v.access = t.access
		v.type = 'i'
	else
		error "invalid uniform value"
	end
	return v
end

local function to_math_v(v)
	return #v == 4 and math3d.vector(v) or math3d.matrix(v)
end

local function to_v(t, h)
	assert(type(t) == "table")
	if t.stage then
		return to_t(t, h)
	end

	local v = {type="u", handle=h}
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

	local setting = fx.setting
	if setting.lighting == "on" then
		new_properties["b_light_info"] = {type = 'b'}
		if use_cluster_shading then
			new_properties["b_light_grids"] = {type='b'}
			new_properties["b_light_index_lists"] = {type='b'}
		end
	end
	return new_properties
end

local function init(material)
    material.fx.setting = load(material.fx.setting)
    material.fx = assetmgr.load_fx(material.fx)

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
                v.value = assetmgr.resource(v.texture).handle
            end
            if v.image then
                v.type = 'i'
                v.value = assetmgr.resource(v.image).handle
            end
        end
    end

    material.properties = generate_properties(material.fx, material.properties)
    local matobj = rmat.material(CMATOBJ, material.state, material.properties)
    material.instance = matobj:instance()
    return material
end

local function loader(filename)
    return init(load(filename))
end

local function unloader()
end

return {
    init = init,
    loader = loader,
    unloader = unloader,
}
