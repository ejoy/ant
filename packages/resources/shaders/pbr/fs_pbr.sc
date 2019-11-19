$input v_normal, v_posWS, v_texcoord0
#include <bgfx_shader.sh>
#include <shaderlib.sh>
#include "common/uniforms.sh"
#include "common/lighting.sh"
#include "common/transform.sh"
#include "common/utils.sh"

uniform vec4 u_IBLparam;
#define u_prefiltered_cube_mip_levels u_IBLparam.x
#define u_scaleIBLAmbient u_IBLparam.y


// material properites
SAMPLER2D(s_basecolor, 0);
uniform vec4 u_basecolor_factor;

SAMPLER2D(s_metallic_roughness, 1);
uniform vec4 u_metallic_roughness_factor;
#define u_roughness_factor  u_metallic_roughness_factor.y
#define u_metallic_factor   u_metallic_roughness_factor.z

SAMPLER2D(s_normal, 2);

SAMPLER2D(s_occlusion, 3);

SAMPLER2D(s_emissive, 4);
uniform vec4 u_emissive_factor;

uniform vec4 u_material_texture_flags;
#define u_basecolor_texture_flag    u_material_texture_flags.x
#define u_metallic_roughness_texture_flag u_metallic_roughness_factor.w
#define u_normal_texture_flag       u_material_texture_flags.y
#define u_occlusion_texture_flag    u_material_texture_flags.z
#define u_emissive_texture_flag     u_material_texture_flags.w

uniform vec4 u_diffuse_factor;
uniform vec4 u_specular_factor;

// IBL
SAMPLERCUBE(s_irradiance, 6);
SAMPLERCUBE(s_prefilteredmap, 7);
SAMPLER2D(s_BRDFLUT, 8);

// alpha
uniform vec4 u_alpha_info;
#define u_alpha_mask u_alpha_info.x
#define u_alpha_mask_cutoff u_alpha_info.y

struct PBRInfo
{
	float NdotL;                  // cos angle between normal and light direction
	float NdotV;                  // cos angle between normal and view direction
	float NdotH;                  // cos angle between normal and half vector
	float LdotH;                  // cos angle between light direction and half vector
	float VdotH;                  // cos angle between view direction and half vector
	float metalness;              // metallic value at the surface
	float perceptual_roughness;   // roughness value, as authored by the model creator (input to shader)
	float alpha_roughness;        // roughness mapped to a more linear change in the roughness (proposed by [2])
	vec3  kD;					  // diffuse color
	vec3  kS;					  // specular color
};

const float c_min_roughness = 0.04;

void get_metallic_roughness(vec2 texcoord, out float metallic, out float perceptual_roughness)
{
    perceptual_roughness = u_roughness_factor;
    metallic = u_metallic_factor;
    if (u_metallic_roughness_texture_flag > 0.0) {
        // Roughness is stored in the 'g' channel, metallic is stored in the 'b' channel.
        // This layout intentionally reserves the 'r' channel for (optional) occlusion map data
        vec4 mrSample 		= texture2D(s_metallic_roughness, texcoord);
        perceptual_roughness= mrSample.g * perceptual_roughness;
        metallic 			= mrSample.b * metallic;
    } else {
        perceptual_roughness= clamp(perceptual_roughness, c_min_roughness, 1.0);
        metallic 			= clamp(metallic, 0.0, 1.0);
    }
}

// Find the normal for this fragment, pulling either from a predefined normal map
// or from the interpolated mesh normal and tangent attributes.
vec3 getNormal(vec3 normalWS, vec3 posWS, vec2 texcoord)
{
    if (u_normal_texture_flag > 0.0){
		//vec3 normalTS = fetch_dxt_normal(s_normal, texcoord, 0.0);
		vec3 normalTS = texture2D(s_normal, texcoord).rgb * 2.0 - 1.0;
	    return normalize(mul(tbn_from_world_pos(normalWS, posWS, texcoord), normalTS));	// TS to WS
    }

    return normalize(normalWS);
}

// Calculation of the lighting contribution from an optional Image Based Light source.
// Precomputed Environment Maps are required uniform inputs and are computed as outlined in [1].
// See our README.md on Environment Maps [3] for additional discussion.
vec3 calc_indirect_lighting_IBL(PBRInfo pbr_inputs, vec3 n, vec3 reflection)
{
	float lod = (pbr_inputs.perceptual_roughness * u_prefiltered_cube_mip_levels);
	// retrieve a scale and bias to F0. See [1], Figure 3
	vec3 brdf = texture2D(s_BRDFLUT, vec2(pbr_inputs.NdotV, 1.0 - pbr_inputs.perceptual_roughness)).rgb;
	// vec3 diffuseLight = toLinear(tonemap(textureCube(s_irradiance, n))).rgb;
	// vec3 specularLight = toLinear(tonemap(textureCubeLod(s_prefilteredmap, reflection, lod))).rgb;

	vec3 diffuseLight = toLinear(textureCube(s_irradiance, n)).rgb;
	vec3 specularLight = toLinear(textureCubeLod(s_prefilteredmap, reflection, lod)).rgb;

	vec3 diffuse = diffuseLight * pbr_inputs.kD;
	vec3 specular = specularLight * (pbr_inputs.kS * brdf.x + brdf.y);

	// For presentation, this allows us to disable IBL terms
	// For presentation, this allows us to disable IBL terms
	diffuse *= u_scaleIBLAmbient;
	specular *= u_scaleIBLAmbient;

	return diffuse + specular;
}

// Basic Lambertian diffuse
// Implementation from Lambert's Photometria https://archive.org/details/lambertsphotome00lambgoog
// See also [1], Equation 1
vec3 lambertian_diffuse(PBRInfo pbr_inputs)
{
	return pbr_inputs.kD / M_PI;
}

float calc_reflectance(vec3 c)
{
	return max(c.r, max(c.g, c.b));
}

float calc_reflectance90(float reflectance)
{
	return clamp(reflectance * 25.0, 0.0, 1.0);
}

// The following equation models the Fresnel reflectance term of the spec equation (aka F())
// Implementation of fresnel from [4], Equation 15
vec3 fresnel_reflection(PBRInfo pbr_inputs)
{
	vec3 r0 	= pbr_inputs.kS;
	vec3 r90 	= calc_reflectance90(calc_reflectance(r0));	// simplied by using 1
	return r0 + (r90 - r0) * pow(saturate(1.0 - pbr_inputs.VdotH), 5.0);
}

// This calculates the specular geometric attenuation (aka G()),
// where rougher material will reflect less light back to the viewer.
// This implementation is based on [1] Equation 4, and we adopt their modifications to
// alpha_roughness as input as originally proposed in [2].
float geometric_occlusion(PBRInfo pbr_inputs)
{
	float NdotL = pbr_inputs.NdotL;
	float NdotV = pbr_inputs.NdotV;
	float r = pbr_inputs.alpha_roughness;

	float sr = r * r;

	float attenuationL = 2.0 * NdotL / (NdotL + sqrt(sr + (1.0 - sr) * (NdotL * NdotL)));
	float attenuationV = 2.0 * NdotV / (NdotV + sqrt(sr + (1.0 - sr) * (NdotV * NdotV)));
	return attenuationL * attenuationV;
}

// The following equation(s) model the distribution of microfacet normals across the area being drawn (aka D())
// Implementation from "Average Irregularity Representation of a Roughened Surface for Ray Reflection" by T. S. Trowbridge, and K. P. Reitz
// Follows the distribution function recommended in the SIGGRAPH 2013 course notes from EPIC Games [1], Equation 3.
float normal_distribution(PBRInfo pbr_inputs)
{
	float roughnessSq = pbr_inputs.alpha_roughness * pbr_inputs.alpha_roughness;
	float f = (pbr_inputs.NdotH * roughnessSq - pbr_inputs.NdotH) * pbr_inputs.NdotH + 1.0;
	return roughnessSq / (M_PI * f * f);
}

vec4 get_basecolor(vec2 texcoord)
{
    if (u_basecolor_texture_flag > 0.0)
		return texture2D_sRGB(s_basecolor, texcoord) * u_basecolor_factor;

	return u_basecolor_factor;
}

vec3 calc_direct_lighting(PBRInfo pbr_info)
{
	// Calculate the shading terms for the microfacet specular shading model
	vec3 F = fresnel_reflection(pbr_info);
	float G = geometric_occlusion(pbr_info);
	float D = normal_distribution(pbr_info);

    // Calculation of analytical lighting contribution
	vec3 diffuse = (1.0 - F) * lambertian_diffuse(pbr_info);
	vec3 specular = F * G * D / (4.0 * pbr_info.NdotL * pbr_info.NdotV);
	// Obtain final intensity as reflectance (BRDF) scaled by the energy of the light (cosine law)
	return pbr_info.NdotL * (diffuse + specular);
}

void modulate_occlusion(vec2 texcoord, inout vec3 color)
{
	//const float u_OcclusionStrength = 1.0f;
	// Apply optional PBR terms for additional (optional) shading
	if (u_occlusion_texture_flag > 0.0) {
		float ao = texture2D(s_occlusion, texcoord).r;
		//color = lerp(color, color * ao, u_OcclusionStrength);
        color *= ao;
	}
}

void add_emissive(vec2 texcoord, inout vec3 color)
{
	if (u_emissive_texture_flag > 0.0) {
		vec3 emissive = texture2D_sRGB(s_emissive, texcoord).rgb * u_emissive_factor;
		color += emissive;
	}
}

float to_alpha_roughness(float perceptual_roughness)
{
	return perceptual_roughness * perceptual_roughness;
}

void main()
{
	// The albedo may be defined from a base texture or a flat color
	vec4 basecolor = get_basecolor(v_texcoord0);

	if (u_alpha_mask == 1.0f) {
		if (basecolor.a < u_alpha_mask_cutoff) {
			discard;
		}
	}

	float metallic, perceptual_roughness;
	get_metallic_roughness(v_texcoord0, metallic, perceptual_roughness);

    // Roughness is authored as perceptual roughness; as is convention,
    // convert to material roughness by squaring the perceptual roughness [2].

	vec3 lowest_f0 = vec3_splat(0.04);
	vec3 kD = basecolor.rgb * (1.0 - lowest_f0);
	kD *= 1.0 - metallic;
	vec3 kS = lerp(lowest_f0, basecolor.rgb, metallic);

	vec3 n = getNormal(v_normal, v_posWS.xyz, v_texcoord0);
	vec3 v = normalize(u_eyepos.xyz - v_posWS.xyz);    // Vector from surface point to camera
	vec3 l = normalize(directional_lightdir[0].xyz);     // Vector from surface point to light
	vec3 h = normalize(l+v);                        // Half vector between both l and v
	vec3 reflection = -normalize(reflect(v, n));
	reflection.y *= -1.0f;

	PBRInfo pbr_inputs;

	pbr_inputs.NdotL 				= clamp(dot(n, l), 0.001, 1.0);
	pbr_inputs.NdotV 				= clamp(abs(dot(n, v)), 0.001, 1.0);
	pbr_inputs.NdotH 				= clamp(dot(n, h), 0.0, 1.0);
	pbr_inputs.LdotH 				= clamp(dot(l, h), 0.0, 1.0);
	pbr_inputs.VdotH 				= clamp(dot(v, h), 0.0, 1.0);
	pbr_inputs.perceptual_roughness = perceptual_roughness;
	pbr_inputs.metalness 			= metallic;
	pbr_inputs.alpha_roughness 		= to_alpha_roughness(perceptual_roughness);
	pbr_inputs.kD 					= kD;
	pbr_inputs.kS 					= kS;

	vec3 color = calc_direct_lighting(pbr_inputs);
	// Calculate lighting contribution from image based lighting source (IBL)
	//color += calc_indirect_lighting_IBL(pbr_inputs, n, reflection);

	modulate_occlusion(v_texcoord0, color);
	add_emissive(v_texcoord0, color);

	gl_FragColor = output_color_sRGB(vec4(color, basecolor.a));
}
