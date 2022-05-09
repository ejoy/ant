local ecs	= ...
local world = ecs.world
local w		= world.w

local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local math3d		= require "math3d"
local bgfx			= require "bgfx"
local rmat			= require "render.material"
local CMATOBJ		= rmat.cobject {
    bgfx = assert(bgfx.CINTERFACE) ,
    math3d = assert(math3d.CINTERFACE),
    encoder = assert(bgfx.encoder_get()),
}

local function texture_value(stage)
	return {stage=stage, value=nil, handle=nil, type='t'}
end

local function buffer_value(stage, access)
	return {stage=stage, access=access, value=nil, type='b'}
end

local function check(properties)
	for k, v in pairs(properties) do
		if v.type == "u" or v.type == "s" then
			local n = 1
			local ut
			if v.stage == nil then
				local function which_uniform_type(mv)
					local vv = math3d.tovalue(mv)
					return #vv == 16 and "m4" or "v4"
				end
				if type(v.value) == "table" then
					n = #v.value
					ut = which_uniform_type(v.value[1])
				else
					ut = which_uniform_type(v.value)
				end
			else
				ut = "s"
			end

			v.handle = bgfx.create_uniform(k, ut, n)
		end
	end
	return properties
end

local SYS_ATTRIBS = rmat.system_attribs(CMATOBJ, check{
	--camera
	u_eyepos				= {type="u", value=mc.ZERO_PT},
	u_exposure_param		= {type="u", value=math3d.vector(16.0, 0.008, 100.0, 0.0)},
	u_camera_param			= {type="u", value=mc.ZERO},
	--lighting
	u_cluster_size			= {type="u", value=mc.ZERO},
	u_cluster_shading_param	= {type="u", value=mc.ZERO},
	u_light_count			= {type="u", value=mc.ZERO},
	b_light_grids			= buffer_value(-1, "r"),
	b_light_index_lists		= buffer_value(-1, "r"),
	b_light_info			= buffer_value(-1, "r"),
	u_time					= {type="u", value=mc.ZERO},

	--IBL
	u_ibl_param				= {type="u", value=mc.ZERO},
	s_irradiance			= texture_value(5),
	s_prefilter				= texture_value(6),
	s_LUT					= texture_value(7),

	--curve world
	--[[
		u_curveworld_param = (flat, base, exp, amp)
		dirWS = mul(u_invView, dirVS)
		dis = length(u_eyepos-posWS);
		offsetWS = (amp*((dis-flat)/base)^exp) * dirWS
		posWS = posWS + offsetWS
	]]
	u_curveworld_param		= {type="u", value=mc.ZERO},	-- flat distance, base distance, exp, amplification
	u_curveworld_dir		= {type="u", value=mc.ZAXIS},	-- dir in view space

	-- shadow
	--   csm
	u_csm_matrix 		= { type="u",
		value = {
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
		}
	},
	u_csm_split_distances= {type="u", value=mc.ZERO},
	u_depth_scale_offset = {type="u", value=mc.ZERO},
	u_shadow_param1		 = {type="u", value=mc.ZERO},
	u_shadow_param2		 = {type="u", value=mc.ZERO},
	s_shadowmap			 = texture_value(8),

	--   omni
	u_omni_matrix = { type = "u",
		value = {
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
			mc.IDENTITY_MAT,
		}
	},

	u_tetra_normal_Green	= {type="u", value=mc.ZERO},
	u_tetra_normal_Yellow	= {type="u", value=mc.ZERO},
	u_tetra_normal_Blue		= {type="u", value=mc.ZERO},
	u_tetra_normal_Red		= {type="u", value=mc.ZERO},

	s_omni_shadowmap	= texture_value(9),
})

local sd			= import_package "ant.settings".setting

local assetmgr		= require "asset"
local ext_material	= require "ext_material"

local function load_material(m, c, setting)
	local fx = assetmgr.load_fx(m.fx, setting)
	local properties = m.properties
	if not properties and #fx.uniforms > 0 then
		properties = {}
	end
	c.fx			= fx
	c.properties	= properties
	c.state			= m.state
	c.stencil		= m.stencil
	return c
end

local imaterial = ecs.interface "imaterial"

function imaterial.set_property(e, who, what)
	--e.render_object.material[who] = what
end

function imaterial.get_property(e, who)
	return e.render_object.material[who]
end

local function init_material(mm)
	if type(mm) == "string" then
		return assetmgr.resource(mm)
	end
	return ext_material.init(mm)
end

local function to_t(t, handle)
	local v = {stage=assert(t.stage), handle=handle}
	if t.texture then
		v.handle = t.texture.handle
		v.type = 't'
	elseif t.image then
		v.handle = t.image.handle
		v.mip = t.mip
		v.access = t.access
		v.type = 'i'
	else
		error "invalid uniform value"
	end
	return v
end

local function to_v(t)
	assert(type(t) == "table")
	local function to_math_v(v)
		return #v == 4 and math3d.vector(v) or math3d.matrix(v)
	end
	if type(t[1]) == "number" then
		return to_math_v(t)
	end
	local res = {}
	for i, v in ipairs(t) do
		res[i] = to_math_v(v)
	end
	return res
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
					local pv = properties[n]
					if pv then
						v = pv.stage and to_t(pv, u.handle) or to_v(pv)
					else
						v = mc.ZERO
					end
					
				end

				new_properties[n] = v
			end
		end
	end

	local setting = fx.setting
	if setting.lighting == "on" then
		new_properties["b_light_info"] = {type = 'b'}
		if sd:data().graphic.cluster_shading ~= 0 then
			new_properties["b_light_grids"] = {type='b'}
			new_properties["b_light_index_lists"] = {type='b'}
		end
	end
	return new_properties
end

local function build_material(mc, filename)
	if filename:match "downsample.material" then
		print ""
	end
	local properties= generate_properties(mc.fx, mc.properties)
	local material = rmat.material(CMATOBJ, mc.state, properties, filename)
	return {
		material = material:instance(),
		--TODO: need remove
		fx 			= mc.fx,
		state 		= mc.state,
		stencil		= mc.stencil,
	}
end

function imaterial.load(mp, setting)
	local mm = assetmgr.resource(mp)
	return build_material(load_material(mm, {}, setting), mp)
end

function imaterial.system_attribs()
	return SYS_ATTRIBS
end

local ms = ecs.system "material_system"
function ms:component_init()
	w:clear "material_result"
    for e in w:select "INIT material:in material_setting?in material_result:new" do
		local mm = load_material(init_material(e.material), {}, e.material_setting)
		e.material_result = build_material(mm, e.material)
	end
end