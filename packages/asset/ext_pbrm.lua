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
	roughness_metallic = {
		texture = pbr_default_path / "roughness_metallic.texture",
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
		tex.path = fs.path(tex.path)
	end
end

local function get_texture(pbrm, name)
	local t = pbrm[name].texture
	return t and t.path or default_pbr_param[name].texture
end

return {
	loader = function (filename)
		local material_loader = assetmgr.get_loader "material"
		local material = material_loader(pbr_material)	--we need multi instances

		local pbrm = assetmgr.load_depiction(filename)

		refine_paths(pbrm)

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
					value=pbrm.basecolor.factor or default_pbr_param.basecolor.factor,
				},
				u_metallic_roughness_factor = {
					type="v4", name="metalllic&roughness factor",
					value={
						0.0, -- keep for occlusion factor
						pbrm.metallic_roughness.roughness_factor or 1,	-- roughness
						pbrm.metallic_roughness.metallic_factor or 1, 	-- metallic
						pbrm.metallic_roughness.texture and 1.0 or 0.0,	-- whether using metallic_roughtness texture or not
					}
				},
				u_emissive_factor = {
					type="v4", name="emissive factor",
					value=pbrm.emissive.factor or default_pbr_param.emissive.factor,
				},
				u_material_texture_flags = {
					type="v4", name="texture flags",
					value={
						pbrm.basecolor.texture and 1.0 or 0.0,
						pbrm.normal.texture and 1.0 or 0.0,
						pbrm.occlusion.texture and 1.0 or 0.0,
						pbrm.emissive.texture and 1.0 or 0.0,
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