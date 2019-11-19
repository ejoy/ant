local assetmgr 	= require "asset"
local assetutil = require "util"
local fs = require "filesystem"

local engine_resource_path = fs.path "/pkg/ant.resources/depiction"

local pbr_material = engine_resource_path / "materials/pbr_default.material"

local pbr_default_path = engine_resource_path / "textures/pbr/default"
local default_pbr_param = {
	basecolor = {
		texture = pbr_default_path / "basecolor.texture",
		factor = {1, 1, 1, 1},
	},
	metallic_roughness = {
		texture = pbr_default_path / "metallic_roughness.texture",
		factor = {1, 1, 0, 0},
	},
	normal = {
		texture = pbr_default_path / "normal.texture",
	},
	occlusion = {
		texture = pbr_default_path / "occlusion.texture",
	},
	emissive = {
		texture = pbr_default_path / "emissive.texture",
		factor = {0, 0, 0, 0},
	},
}

local function refine_paths(pbrm)
	for k, v in pairs(pbrm) do
		local tex = v.texture
		if tex then
			tex.path = fs.path(tex.path)
		end
	end
end

local function texture_path(pbrm, name)
	local p = pbrm[name]
	if p then
		local t = pbrm[name].texture
		if t then
			return t.path
		end
	end
end

local function get_texture(pbrm, name)
	return texture_path(pbrm, name) or default_pbr_param[name].texture
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
	return texture_path(pbrm, name) and 1.0 or 0.0
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

return {
	loader = function (filename)
		local material_loader = assetmgr.get_loader "material"
		local material = material_loader(pbr_material)	--we need multi instances

		local pbrm = assetmgr.load_depiction(filename)

		refine_paths(pbrm)

		local metallic_factor, roughness_factor = 
			get_metallic_roughness_factor(pbrm)

		local properties = {
			textures = {
				s_basecolor = {
					type="texture", name="BaseColor texture", stage=0, 
					ref_path=get_texture(pbrm, "basecolor")
				},
				s_metallic_roughness = {
					type="texture", name="roughness metallic texutre", stage=1,
					ref_path=get_texture(pbrm, "metallic_roughness")
				},
				s_normal = {
					type="texture", name="normal texture", stage=2,
					ref_path=get_texture(pbrm, "normal")
				},
				s_occlusion = {
					type="texture", name="occlusion texture", stage=3,
					ref_path=get_texture(pbrm, "occlusion")
				},
				s_emissive = {
					type="texture", name="emissive texture", stage=4,
					ref_path=get_texture(pbrm, "emissive")
				},
			},
			uniforms = {
				u_basecolor_factor = {
					type="color", name="base color factor",
					value=get_property_factor(pbrm, "basecolor"),
				},
				u_metallic_roughness_factor = {
					type="v4", name="metalllic&roughness factor",
					value={
						0.0, -- keep for occlusion factor
						roughness_factor,
						metallic_factor,
						texture_flag(pbrm, "metallic_roughness"),-- whether using metallic_roughtness texture or not
					}
				},
				u_emissive_factor = {
					type="v4", name="emissive factor",
					value=get_property_factor(pbrm, "emissive"),
				},
				u_material_texture_flags = {
					type="v4", name="texture flags",
					value={
						texture_flag(pbrm, "basecolor"),
						texture_flag(pbrm, "normal"),
						texture_flag(pbrm, "occlusion"),
						texture_flag(pbrm, "emissive"),
					},
				},
				u_IBLparam = {
					type="v4", name="IBL sample parameter",
					value={
						1.0, -- perfilter cubemap mip levels
						1.0, -- IBL indirect lighting scale
						0.0, 0.0,
					}
				},
				u_alpha_info = {
					type="v4", name="alpha test/mask info",
					value={
						pbrm.alphaMode == "OPAQUE" and 0.0 or 1.0, --u_alpha_mask
						pbrm.alphaCutoff or 0.0,
						0.0, 0.0,
					}
				}
			},
		}

		material.properties = assetutil.load_material_properties(properties)
		return material
	end,
}