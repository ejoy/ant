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
	float metallic;              // metallic value at the surface
	float roughness;   // roughness value, as authored by the model creator (input to shader)
	float alpha_roughness;        // roughness mapped to a more linear change in the roughness (proposed by [2])
};

const float c_min_roughness = 0.04;

void get_metallic_roughness(vec2 texcoord, out float metallic, out float roughness)
{
    roughness = u_roughness_factor;
    metallic = u_metallic_factor;
    if (u_metallic_roughness_texture_flag > 0.0) {
        // Roughness is stored in the 'g' channel, metallic is stored in the 'b' channel.
        // This layout intentionally reserves the 'r' channel for (optional) occlusion map data
        vec4 mrSample 		= texture2D(s_metallic_roughness, texcoord);
        roughness= mrSample.g * roughness;
        metallic 			= mrSample.b * metallic;
    } else {
        roughness= clamp(roughness, c_min_roughness, 1.0);
        metallic 			= clamp(metallic, 0.0, 1.0);
    }
}

// Find the normal for this fragment, pulling either from a predefined normal map
// or from the interpolated mesh normal and tangent attributes.
vec3 getNormal(vec3 normalWS, vec3 posWS, vec2 texcoord)
{
    if (u_normal_texture_flag > 0.0){
		vec3 normalTS = fetch_compress_normal(s_normal, texcoord, 0.0);
	    return normalize(mul(tbn_from_world_pos(normalWS, posWS, texcoord), normalTS));	// TS to WS
    }

    return normalize(normalWS);
}

vec3 lambertian_diffuse(vec3 basecolor)
{
	return basecolor / M_PI;
}

vec4 get_basecolor(vec2 texcoord)
{
    if (u_basecolor_texture_flag > 0.0)
		return texture2D_sRGB(s_basecolor, texcoord) * u_basecolor_factor;

	return u_basecolor_factor;
}

float DistributionGGX(float NdotH, float alpha_roughness)
{
    float a2 = alpha_roughness * alpha_roughness;

    float NdotH2 = NdotH*NdotH;

    float nom   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = M_PI * denom * denom;

    return nom / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}

float GeometrySmith(float NdotV, float NdotL, float roughness)
{
    return 	GeometrySchlickGGX(NdotV, roughness) * 
    		GeometrySchlickGGX(NdotL, roughness);
}

vec3 fresnelSchlick(float NdotH, vec3 F0, vec3 F90)
{
	return F0 + (F90 - F0) * pow(1.0 - NdotH, 5.0);
}

vec3 fresnelSchlickSimple(float NdotH, vec3 F0)
{
    return fresnelSchlick(NdotH, F0, vec3_splat(1.0));
}

vec3 fresnelSchlickRoughness(float NdotH, vec3 F0, float roughness)
{
	vec3 F90 = max(vec3_splat(1.0 - roughness), F0);
    return fresnelSchlick(NdotH, F0, F90);
}

vec3 directional_light_radiance()
{
	return directional_color[0].rgb * directional_intensity[0].r;
}

vec3 diffuse_percent(vec3 kS, float metallic)
{
	vec3 kD = vec3_splat(1.0) - kS;
	return kD * (1.0 - metallic);
}

vec3 calc_direct_lighting(PBRInfo pbr_info, vec3 light_radiance, vec3 basecolor, vec3 F0)
{
	float N = DistributionGGX(pbr_info.NdotH, pbr_info.alpha_roughness);
	float G = GeometrySmith(pbr_info.NdotV, pbr_info.NdotL, pbr_info.roughness);
	vec3  F = fresnelSchlickSimple(pbr_info.NdotH, F0);

	vec3 specular = (N * G * F) / (4 * pbr_info.NdotV * pbr_info.NdotV + 0.001);

	vec3 kD = diffuse_percent(F, pbr_info.metallic);
	vec3 diffuse = kD * lambertian_diffuse(basecolor);

	return (diffuse + specular) * light_radiance * pbr_info.NdotL; 
}

vec3 calc_indirect_lighting_IBL(PBRInfo pbr_info, vec3 N, vec3 R, vec3 basecolor, vec3 F0)
{
	vec3 F = fresnelSchlickRoughness(pbr_info.NdotH, F0, pbr_info.roughness);

#define MAX_REFLECTION_LOD 4.0
    vec3 prefiltered = textureCubeLod(s_prefilteredmap, R, pbr_info.roughness * MAX_REFLECTION_LOD).rgb;
    vec2 brdf  = texture2D(s_BRDFLUT, vec2(pbr_info.NdotV, pbr_info.roughness)).rg;
    vec3 specular = prefiltered * (F * brdf.x + brdf.y);

	vec3 kD = diffuse_percent(F, pbr_info.metallic);

	vec3 irradiance = textureCube(s_irradiance, N).rgb;
    vec3 diffuse    = kD * irradiance * basecolor;
	return diffuse + specular;
}

void modulate_occlusion(vec2 texcoord, inout vec3 indirect_color)
{
	//const float u_OcclusionStrength = 1.0f;
	// Apply optional PBR terms for additional (optional) shading
	if (u_occlusion_texture_flag > 0.0) {
		float ao = texture2D(s_occlusion, texcoord).r;
		//color = lerp(color, color * ao, u_OcclusionStrength);
        indirect_color *= ao;
	}
}

void add_emissive(vec2 texcoord, inout vec3 color)
{
	if (u_emissive_texture_flag > 0.0) {
		vec3 emissive = texture2D_sRGB(s_emissive, texcoord).rgb * u_emissive_factor.rgb;
		color += emissive;
	}
}

float to_alpha_roughness(float roughness)
{
	return roughness * roughness;
}

void main()
{
	vec4 basecolor = get_basecolor(v_texcoord0);

	float metallic, roughness;
	get_metallic_roughness(v_texcoord0, metallic, roughness);

	vec3 N = getNormal(v_normal, v_posWS.xyz, v_texcoord0);
	vec3 V = normalize(u_eyepos.xyz - v_posWS.xyz);
	vec3 L = normalize(directional_lightdir[0].xyz);
	vec3 H = normalize(L+V);
	vec3 R = normalize(reflect(-V, N));

	PBRInfo pbr_inputs;

	pbr_inputs.NdotL 			= max(dot(N, L), 0.0);
	pbr_inputs.NdotV 			= max(dot(N, V), 0.0);
	pbr_inputs.NdotH 			= max(dot(N, H), 0.0);
	pbr_inputs.LdotH 			= max(dot(L, H), 0.0);
	pbr_inputs.VdotH 			= max(dot(V, H), 0.0);
	pbr_inputs.roughness 		= roughness;
	pbr_inputs.metallic 		= metallic;
	pbr_inputs.alpha_roughness 	= to_alpha_roughness(roughness);

	vec3 F0 = mix(vec3_splat(0.04), basecolor, metallic);
	vec3 color = calc_direct_lighting(pbr_inputs, directional_light_radiance(), basecolor.rgb, F0);
	
	// vec3 indirect_color = calc_indirect_lighting_IBL(pbr_inputs, N, R, basecolor.rgb, F0);
	// modulate_occlusion(v_texcoord0, indirect_color);
	//color += indirect_color;

	add_emissive(v_texcoord0, color);

	gl_FragColor = output_color_sRGB(vec4(color, basecolor.a));
}
