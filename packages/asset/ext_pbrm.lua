local ecs = ...
local world = ecs.world

local assetmgr 	= require "asset"

local default_pbr_param = {
	basecolor = {
		texture = world.component:resource "/pkg/ant.resources/textures/pbr/default/basecolor.texture",
		factor = {1, 1, 1, 1},
	},
	metallic_roughness = {
		texture = world.component:resource "/pkg/ant.resources/textures/pbr/default/metallic_roughness.texture",
		factor = {1, 1, 0, 0},
	},
	normal = {
		texture = world.component:resource "/pkg/ant.resources/textures/pbr/default/normal.texture",
	},
	occlusion = {
		texture = world.component:resource "/pkg/ant.resources/textures/pbr/default/occlusion.texture",
	},
	emissive = {
		texture = world.component:resource "/pkg/ant.resources/textures/pbr/default/emissive.texture",
		factor = {0, 0, 0, 0},
	},
}

local function get_texture_obj(pbrm, name)
	local p = pbrm[name]
	if p then
		return pbrm[name].texture
	end
end

local function get_texture(pbrm, name)
	return get_texture_obj(pbrm, name) or default_pbr_param[name].texture
end

local function property_factor(pbrm, name)
	local p = pbrm[name]
	if p then
		return p.factor
	end
end

local function get_property_factor(pbrm, name)
	local f = property_factor(pbrm, name)
	return f or default_pbr_param[name].factor
end

local function texture_flag(pbrm, name)
	return get_texture_obj(pbrm, name) and 1.0 or 0.0
end

local function get_metallic_roughness_factor(pbrm)
	local mr = pbrm.metallic_roughness
	if mr then
		local m = mr.metallic_factor or 1.0
		local r = mr.roughness_factor or 1.0
		return m, r
	end
	return 1.0, 1.0
end

local m = ecs.component "pbrm"

function m:init()
	local pbrm = self
	local materialfile = pbrm.materialfile or "/pkg/ant.resources/materials/pbr_default.material"
	local material = assetmgr.patch(world.component:resource(materialfile), {})

	local metallic_factor, roughness_factor = get_metallic_roughness_factor(pbrm)
	material.properties = {
		textures = {
			s_basecolor = world.component:mat_texture {
				type="texture", stage=0,
				texture=get_texture(pbrm, "basecolor")
			},
			s_metallic_roughness = world.component:mat_texture {
				type="texture", stage=1,
				texture=get_texture(pbrm, "metallic_roughness")
			},
			s_normal = world.component:mat_texture {
				type="texture", stage=2,
				texture=get_texture(pbrm, "normal")
			},
			s_occlusion = world.component:mat_texture {
				type="texture", stage=3,
				texture=get_texture(pbrm, "occlusion")
			},
			s_emissive = world.component:mat_texture {
				type="texture", stage=4,
				texture=get_texture(pbrm, "emissive")
			},
		},
		uniforms = {
			u_basecolor_factor = world.component:uniform {
				type="color",
				value={get_property_factor(pbrm, "basecolor")},
			},
			u_metallic_roughness_factor = world.component:uniform {
				type="v4",
				value={{
					0.0, -- keep for occlusion factor
					roughness_factor,
					metallic_factor,
					texture_flag(pbrm, "metallic_roughness"),-- whether using metallic_roughtness texture or not
				}}
			},
			u_emissive_factor = world.component:uniform {
				type="v4",
				value={get_property_factor(pbrm, "emissive")},
			},
			u_material_texture_flags = world.component:uniform {
				type="v4",
				value={{
					texture_flag(pbrm, "basecolor"),
					texture_flag(pbrm, "normal"),
					texture_flag(pbrm, "occlusion"),
					texture_flag(pbrm, "emissive"),
				}},
			},
			u_IBLparam = world.component:uniform {
				type="v4",
				value={{
					1.0, -- perfilter cubemap mip levels
					1.0, -- IBL indirect lighting scale
					0.0, 0.0,
				}}
			},
			u_alpha_info = world.component:uniform {
				type="v4",
				value={{
					pbrm.alphaMode == "OPAQUE" and 0.0 or 1.0, --u_alpha_mask
					pbrm.alphaCutoff or 0.0,
					0.0, 0.0,
				}}
			}
		},
	}
	return material
end
