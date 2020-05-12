local assetmgr 	= require "asset"
local fs = require "filesystem"

local default_pbr_param = {
	basecolor = {
		texture = "/pkg/ant.resources/textures/pbr/default/basecolor.texture",
		factor = {1, 1, 1, 1},
	},
	metallic_roughness = {
		texture = "/pkg/ant.resources/textures/pbr/default/metallic_roughness.texture",
		factor = {1, 1, 0, 0},
	},
	normal = {
		texture = "/pkg/ant.resources/textures/pbr/default/normal.texture",
	},
	occlusion = {
		texture = "/pkg/ant.resources/textures/pbr/default/occlusion.texture",
	},
	emissive = {
		texture = "/pkg/ant.resources/textures/pbr/default/emissive.texture",
		factor = {0, 0, 0, 0},
	},
}

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
	loader = function (filename, data)
		local material = assetmgr.load_depiction("/pkg/ant.resources/materials/pbr_default.material")

		local pbrm = data or assetmgr.load_depiction(filename)

		--refine_paths(pbrm)

		local metallic_factor, roughness_factor = get_metallic_roughness_factor(pbrm)

		material.properties = {
			textures = {
				s_basecolor = {
					type="texture", stage=0,
					texture=get_texture(pbrm, "basecolor")
				},
				s_metallic_roughness = {
					type="texture", stage=1,
					texture=get_texture(pbrm, "metallic_roughness")
				},
				s_normal = {
					type="texture", stage=2,
					texture=get_texture(pbrm, "normal")
				},
				s_occlusion = {
					type="texture", stage=3,
					texture=get_texture(pbrm, "occlusion")
				},
				s_emissive = {
					type="texture", stage=4,
					texture=get_texture(pbrm, "emissive")
				},
			},
			uniforms = {
				u_basecolor_factor = {
					type="color",
					value={get_property_factor(pbrm, "basecolor")},
				},
				u_metallic_roughness_factor = {
					type="v4",
					value={{
						0.0, -- keep for occlusion factor
						roughness_factor,
						metallic_factor,
						texture_flag(pbrm, "metallic_roughness"),-- whether using metallic_roughtness texture or not
					}}
				},
				u_emissive_factor = {
					type="v4",
					value={get_property_factor(pbrm, "emissive")},
				},
				u_material_texture_flags = {
					type="v4",
					value={{
						texture_flag(pbrm, "basecolor"),
						texture_flag(pbrm, "normal"),
						texture_flag(pbrm, "occlusion"),
						texture_flag(pbrm, "emissive"),
					}},
				},
				u_IBLparam = {
					type="v4",
					value={{
						1.0, -- perfilter cubemap mip levels
						1.0, -- IBL indirect lighting scale
						0.0, 0.0,
					}}
				},
				u_alpha_info = {
					type="v4",
					value={{
						pbrm.alphaMode == "OPAQUE" and 0.0 or 1.0, --u_alpha_mask
						pbrm.alphaCutoff or 0.0,
						0.0, 0.0,
					}}
				}
			},
		}

		local material_loader = assetmgr.get_loader "material"
		return material_loader(nil, material)
	end,
}