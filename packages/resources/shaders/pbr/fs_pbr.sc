#include "common/inputs.sh"

#ifdef MATERIAL_UNLIT
#define OUTPUT_NORMAL
#define OUTPUT_WORLDPOS
#else
#define OUTPUT_NORMAL   v_normal
#define OUTPUT_WORLDPOS v_posWS
#endif 

$input v_texcoord0 OUTPUT_WORLDPOS OUTPUT_NORMAL OUTPUT_TANGENT OUTPUT_BITANGENT OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0

#include <bgfx_shader.sh>
#include <bgfx_compute.sh>
#include <shaderlib.sh>
#include "common/camera.sh"
#include "common/lighting.sh"
#include "common/transform.sh"
#include "common/utils.sh"
#include "common/cluster_shading.sh"
#include "common/constants.sh"
#include "pbr/pbr.sh"

#ifdef UV_MOTION
#include "common/uvmotion.sh"
#endif //UV_MOTION

#ifdef ENABLE_SHADOW
#include "common/shadow.sh"
#define v_distanceVS v_posWS.w
#endif //ENABLE_SHADOW

// material properites
SAMPLER2D(s_basecolor,          0);
SAMPLER2D(s_metallic_roughness, 1);
SAMPLER2D(s_normal,             2);
SAMPLER2D(s_emissive,           3);
SAMPLER2D(s_occlusion,          4);

// IBL
SAMPLERCUBE(s_irradiance,       5);
SAMPLERCUBE(s_prefilter,        6);
SAMPLER2D(s_LUT,                7);

#ifdef USING_LIGHTMAP
SAMPLER2D(s_lightmap,           8);
#endif //USING_LIGHTMAP

uniform vec4 u_basecolor_factor;
uniform vec4 u_emissive_factor;
uniform vec4 u_pbr_factor;
#define u_metallic_factor    u_pbr_factor.x
#define u_roughness_factor   u_pbr_factor.y
#define u_alpha_mask_cutoff  u_pbr_factor.z
#define u_occlusion_strength u_pbr_factor.w

uniform vec4 u_ibl_param;
#define u_ibl_prefilter_mipmap_count    u_ibl_param.x
#define u_ibl_indirect_intensity        u_ibl_param.y

vec4 get_basecolor(vec2 texcoord, vec4 basecolor)
{
    basecolor *= u_basecolor_factor;
#ifdef HAS_BASECOLOR_TEXTURE
    basecolor *= texture2D(s_basecolor, texcoord);
#endif//HAS_BASECOLOR_TEXTURE
    return basecolor;
}

vec3 get_normal_by_tbn(mat3 tbn, vec3 normal, vec2 texcoord)
{
#ifdef HAS_NORMAL_TEXTURE
	vec3 normalTS = fetch_bc5_normal(s_normal, texcoord);
	return instMul(normalTS, tbn);
#else //!HAS_NORMAL_TEXTURE
    return normal;
#endif //HAS_NORMAL_TEXTURE
}

vec3 get_normal(vec3 tangent, vec3 bitangent, vec3 normal, vec2 texcoord)
{
    mat3 tbn = mtxFromCols(tangent, bitangent, normal);
    return get_normal_by_tbn(tbn, normal, texcoord);
}


void get_metallic_roughness(out float metallic, out float roughness, vec2 uv)
{
    metallic = u_metallic_factor;
    roughness = u_roughness_factor;

#ifdef HAS_METALLIC_ROUGHNESS_TEXTURE
    // Roughness is stored in the 'g' channel, metallic is stored in the 'b' channel.
    // This layout intentionally reserves the 'r' channel for (optional) occlusion map data
    vec4 mrSample = texture2D(s_metallic_roughness, uv);
    roughness *= mrSample.g;
    metallic *= mrSample.b;
#endif

    roughness  = clamp(roughness, 0.0, 1.0);
    metallic   = clamp(metallic, 0.0, 1.0);
}

vec3 get_IBL_radiance_Lambertian(vec3 n, vec3 diffuseColor)
{
    return textureCube(s_irradiance, n).rgb * diffuseColor;
}

vec3 get_IBL_radiance_GGX(vec3 N, vec3 V, float NdotV, float roughness, vec3 specular_color)
{
    float lod = clamp(roughness * u_ibl_prefilter_mipmap_count, 0.0, u_ibl_prefilter_mipmap_count);
    vec3 reflection = normalize(reflect(-V, N));

    vec2 lut_uv = clamp(vec2(NdotV, roughness), vec2_splat(0.0), vec2_splat(1.0));
    vec2 lut = texture2D(s_LUT, lut_uv).rg;
    vec3 specular_light = textureCubeLod(s_prefilter, reflection, lod).rgb;
    return specular_light * (specular_color * lut.x + lut.y);
}

material_info get_material_info(vec3 basecolor, vec2 uv)
{
    material_info mi;
    get_metallic_roughness(mi.metallic, mi.roughness, uv);
    // Roughness is authored as perceptual roughness; as is convention,
    // convert to material roughness by squaring the perceptual roughness.
    mi.alpha_roughness = mi.roughness * mi.roughness;

    // Achromatic f0 based on IOR.
    vec3 f0_ior = vec3_splat(MIN_ROUGHNESS);
    calc_reflectance(f0_ior, basecolor, mi);
    return mi;
}

void main()
{
    vec2 uv =
#ifdef UV_MOTION
	uv_motion(v_texcoord0);
#else //!UV_MOTION
	v_texcoord0;
#endif //UV_MOTION

    vec4 basecolor = get_basecolor(uv, 
#ifdef WITH_COLOR_ATTRIB
    v_color0);
#else //!WITH_COLOR_ATTRIB
     vec4_splat(1.0));
#endif //WITH_COLOR_ATTRIB

#ifdef ALPHAMODE_OPAQUE
    basecolor.a = u_alpha_mask_cutoff;
#endif //ALPHAMODE_OPAQUE

#ifdef ALPHAMODE_MASK
    // Late discard to avoid samplig artifacts. See https://github.com/KhronosGroup/glTF-Sample-Viewer/issues/267
    if(basecolor.a < u_alpha_mask_cutoff)
        discard;
    basecolor.a = 1.0;
#endif //ALPHAMODE_MASK

#ifdef HAS_EMISSIVE_TEXTURE
    basecolor.rgb += texture2D(s_emissive, uv).rgb * u_emissive_factor.rgb;
#endif //HAS_EMISSIVE_TEXTURE

#ifdef MATERIAL_UNLIT
    gl_FragColor = basecolor;
#else //!MATERIAL_UNLIT
    vec3 V = normalize(u_eyepos.xyz - v_posWS.xyz);

#ifdef WITH_TANGENT_ATTRIB
    vec3 N = get_normal(v_tangent, v_bitangent, v_normal, uv);
#else //!WITH_TANGENT_ATTRIB
    vec3 N = get_normal_by_tbn(tbn_from_world_pos(v_normal, v_posWS.xyz, uv), v_normal, uv);
#endif //WITH_TANGENT_ATTRIB

    material_info mi = get_material_info(basecolor.rgb, uv);

    // LIGHTING
    vec3 color = vec3_splat(0.0);

    float NdotV = clamp_dot(N, V);

#ifdef CLUSTER_SHADING
	uint cluster_idx = which_cluster(gl_FragCoord.xyz);

    uint cluster_count = u_cluster_size.x * u_cluster_size.y * u_cluster_size.z;
    cluster_idx = clamp(cluster_idx, 0, cluster_count-1);
	light_grid g; load_light_grid(b_light_grids, cluster_idx, g);
	uint iend = g.offset + g.count;

    //TODO: need fix
    int directional_idx = -1;
	for (uint ii=g.offset; ii<iend; ++ii)
	{
		uint ilight = b_light_index_lists[ii];
#else //!CLUSTER_SHADING
	for (uint ilight=0; ilight<u_light_count[0]; ++ilight)
	{
#endif //CLUSTER_SHADING
        light_info l; load_light_info(b_lights, ilight, l);

        #ifdef USING_LIGHTMAP
        if (IS_DIRECTIONAL_LIGHT(l.type))
        {
            directional_idx = ilight;
        }
        else
        #endif 
        {
            color += get_light_radiance(l, v_posWS.xyz, N, V, NdotV, mi);
        }
    }

#ifdef USING_LIGHTMAP
    if (directional_idx >= 0)
    {
        vec4 irradiance = texture2D(s_lightmap, v_texcoord1);
        vec3 c = basecolor.rgb * irradiance.rgb * PI * 0.5;
        color.rgb += c;
    }
#else //!USING_LIGHTMAP

    #ifdef ENABLE_SHADOW
	color = shadow_visibility(v_distanceVS, vec4(v_posWS.xyz, 1.0), color);
    #endif //ENABLE_SHADOW

    // Calculate lighting contribution from image based lighting source (IBL)
#ifdef ENABLE_IBL
    vec3 indirect_color =   get_IBL_radiance_GGX(N, V, NdotV, mi.roughness, mi.f0) +
                            get_IBL_radiance_Lambertian(N, mi.albedo);
    indirect_color *= u_ibl_indirect_intensity;
    color += indirect_color;
#endif //ENABLE_IBL

#ifdef HAS_OCCLUSION_TEXTURE
    float ao = texture2D(s_occlusion,  uv).r;
    color  += lerp(color, color * ao, u_occlusion_strength);
#endif //HAS_OCCLUSION_TEXTURE

#endif //USING_LIGHTMAP
    gl_FragColor = vec4(color, basecolor.a);
#endif //MATERIAL_UNLIT


}
