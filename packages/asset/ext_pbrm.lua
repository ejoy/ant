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
	metal_roughness = {
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
		tex.path = fs.path(tex.path)
	end
end

return {
	loader = function (filename)
		local material_loader = assetmgr.get_loader "material"
		local material = material_loader(pbr_material)	--we need multi instances

		local pbrm = assetmgr.load_depiction(filename)

		refine_paths(pbrm)

		material.properties = assetutil.load_material_properties{
			textures = {
				s_basecolor = {
					type="texture", name="BaseColor texture", stage=0, 
					ref_path=pbrm.basecolor.texture.path or default_pbr_param.basecolor.texture
				},
				s_metal_roughness = {
					type="texture", name="metal roughness texutre", stage=1,
					ref_path=pbrm.metallic_roughness.texture.path or default_pbr_param.metal_roughness.texture
				},
				s_normal = {
					type="texture", name="normal texture", stage=2,
					ref_path=pbrm.normal.texture.path or default_pbr_param.normal.texture,
				},
				s_occlusion = {
					type="texture", name="occlusion texture", stage=3,
					ref_path=pbrm.occlusion.texture.path or default_pbr_param.occlusion.texture,
				},
				s_emissive = {
					type="texture", name="emissive texture", stage=4,
					ref_path=pbrm.emissive.texture.path or default_pbr_param.emissive.texture,
				},
			},
			uniforms = {
				u_basecolor_factor = {
					type="color", name="base color factor",
					value=pbrm.basecolor.factor or default_pbr_param.basecolor.factor,
				},
				u_metal_roughness_factor = {
					type="v4", name="metal roughness factor",
					value={
						pbrm.metallic_roughness.factor[1] or 1, 
						pbrm.metallic_roughness.factor[2] or 1,
						0, 0
					}
				},
				u_emissive_factor = {
					type="v4", name="emissive factor",
					value=pbrm.emissive.factor or default_pbr_param.emissive.factor,
				}
			},
		}
		return material
	end,
}