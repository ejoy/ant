$input v_texcoord0, v_posWS, v_normal, v_tangent, v_bitangent
#include <bgfx_shader.sh>
#include <bgfx_compute.sh>
#include <shaderlib.sh>
#include "common/lighting.sh"
#include "common/transform.sh"
#include "common/utils.sh"
#include "common/cluster_shading.sh"
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
SAMPLER2D(s_metallic_roughness, 1);	// r channel for metallic, g channel for roughness, occlusion map should put in b channel
SAMPLER2D(s_normal,             2);
SAMPLER2D(s_emissive,           3);
SAMPLER2D(s_occlusion,          4);
// IBL
SAMPLERCUBE(s_irradiance,       5);
SAMPLERCUBE(s_prefilter,        6);
SAMPLER2D(s_LUT,                7);

uniform vec4 u_basecolor_factor;
uniform vec4 u_emissive_factor;
uniform vec4 u_pbr_factor;
#define u_metallic_factor    u_pbr_factor.x
#define u_roughness_factor   u_pbr_factor.y
#define u_alpha_mask_cutoff  u_pbr_factor.z
#define u_occlusion_strength u_pbr_factor.w

uniform vec4 u_ibl_param;
#define u_ibl_prefilter_mipmap_count u_ibl_param.x

struct material_info
{
    float roughness;      // roughness value, as authored by the model creator (input to shader)
    vec3 f0;                        // full reflectance color (n incidence angle)

    float alpha_roughness;           // roughness mapped to a more linear change in the roughness (proposed by [2])
    vec3 albedo;

    vec3 f90;                       // reflectance color at grazing angle
    float metallic;

    //vec3 normal;
    vec3 basecolor;
};

vec4 get_basecolor(vec2 texcoord)
{
    #ifdef HAS_BASECOLOR_TEXTURE
        return u_basecolor_factor * texture2D(s_basecolor, texcoord);
    #else //!HAS_BASECOLOR_TEXTURE
        return u_basecolor_factor;
    #endif//HAS_BASECOLOR_TEXTURE
}

vec3 get_normal(vec3 tangent, vec3 bitangent, vec3 normal, vec2 texcoord)
{
    #ifdef HAS_NORMAL_TEXTURE
		mat3 tbn = mtxFromCols(tangent, bitangent, normal);
		vec3 normalTS = fetch_bc5_normal(s_normal, texcoord);
		return instMul(normalTS, tbn);
    #else //!HAS_NORMAL_TEXTURE
        return normal;
	#endif //HAS_NORMAL_TEXTURE
}


material_info get_metallic_roughness(material_info info, vec2 uv, float f0_ior)
{
    info.metallic = u_metallic_factor;
    info.roughness = u_roughness_factor;

#ifdef HAS_METALLIC_ROUGHNESS_TEXTURE
    // Roughness is stored in the 'g' channel, metallic is stored in the 'b' channel.
    // This layout intentionally reserves the 'r' channel for (optional) occlusion map data
    vec4 mrSample = texture2D(s_metallic_roughness, uv);
    info.roughness *= mrSample.g;
    info.metallic *= mrSample.b;
#endif

    // Achromatic f0 based on IOR.
    info.albedo = mix(info.basecolor.rgb * (1.0 - f0_ior),  vec3_splat(0.0), info.metallic);
    info.f0 = mix(vec3_splat(f0_ior), info.basecolor.rgb, info.metallic);

    return info;
}

float clamp_dot(vec3 x, vec3 y)
{
    return clamp(dot(x, y), 0.0, 1.0);
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

void main()
{
#ifdef UV_MOTION
	vec2 uv = uv_motion(v_texcoord0);
#else //!UV_MOTION
	vec2 uv = v_texcoord0;
#endif //UV_MOTION
    vec4 basecolor = get_basecolor(uv);

#ifdef MATERIAL_UNLIT
    gl_FragColor = basecolor;
    return;
#endif

#ifdef ALPHAMODE_OPAQUE
    basecolor.a = u_alpha_mask_cutoff;
#endif

#ifdef ALPHAMODE_MASK
    // Late discard to avaoid samplig artifacts. See https://github.com/KhronosGroup/glTF-Sample-Viewer/issues/267
    if(basecolor.a < u_alpha_mask_cutoff)
    {
        discard;
    }
    basecolor.a = 1.0;
#endif

    vec3 V = normalize(u_eyepos.xyz - v_posWS.xyz);
    vec3 N = get_normal(v_tangent, v_bitangent, v_normal, uv);

    material_info mi;
    mi.basecolor  = basecolor.rgb;
    mi            = get_metallic_roughness(mi, uv, MIN_ROUGHNESS);
    mi.roughness  = clamp(mi.roughness, 0.0, 1.0);
    mi.metallic   = clamp(mi.metallic, 0.0, 1.0);

    // Roughness is authored as perceptual roughness; as is convention,
    // convert to material roughness by squaring the perceptual roughness.
    mi.alpha_roughness = mi.roughness * mi.roughness;

    // Compute reflectance.
    float reflectance = max(mi.f0.r, max(mi.f0.g, mi.f0.b));

    // Anything less than 2% is physically impossible and is instead considered to be shadowing. Compare to "Real-Time-Rendering" 4th editon on page 325.
    mi.f90 = vec3_splat(clamp(reflectance * 50.0, 0.0, 1.0));

    //mi.normal = N;

    // LIGHTING
    vec3 f_specular = vec3_splat(0.0);
    vec3 f_diffuse = vec3_splat(0.0);

    float NdotV = clamp_dot(N, V);

    // Calculate lighting contribution from image based lighting source (IBL)
#ifdef ENABLE_IBL
    f_specular += get_IBL_radiance_GGX(N, V, NdotV, mi.roughness, mi.f0);
    f_diffuse += get_IBL_radiance_Lambertian(N, mi.albedo);
#endif

#ifdef HAS_OCCLUSION_TEXTURE
    float ao = texture2D(s_occlusion,  uv).r;
    f_diffuse = mix(f_diffuse, f_diffuse * ao, u_occlusion_strength);
    // apply ambient occlusion too all lighting that is not punctual
    f_specular = mix(f_specular, f_specular * ao, u_occlusion_strength);
#endif

#ifdef CLUSTER_SHADING
	uint cluster_idx = which_cluster(gl_FragCoord.xyz);

	light_grid g; load_light_grid(b_light_grids, cluster_idx, g);
	uint iend = g.offset + g.count;
	for (uint ii=g.offset; ii<iend; ++ii)
	{
		uint ilight = b_light_index_lists[ii];
#else //!CLUSTER_SHADING
	for (uint ilight=0; ilight<u_light_count[0]; ++ilight)
	{
#endif //CLUSTER_SHADING
        light_info l; load_light_info(b_lights, ilight, l);

        vec3 pt2l = l.dir;
        float attenuation = 1.0;
        if(!IS_DIRECTIONAL_LIGHT(l.type))
        {
            pt2l = l.pos - v_posWS.xyz;
            attenuation = get_range_attenuation(l.range, length(pt2l));
            if (IS_SPOT_LIGHT(l.type))
            {
                attenuation *= get_spot_attenuation(pt2l, l.dir, l.outter_cutoff, l.inner_cutoff);
            }
        }

        vec3 intensity = attenuation * l.intensity * l.color.rgb;

        vec3 L = normalize(pt2l);
        vec3 H = normalize(L+V);
        float NdotL = clamp_dot(N, L);
        float NdotH = clamp_dot(N, H);
        float LdotH = clamp_dot(L, H);
        float VdotH = clamp_dot(V, H);

        if (NdotL > 0.0 || NdotV > 0.0)
        {
            // Calculation of analytical light
            // https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#acknowledgments AppendixB
            f_diffuse += intensity * NdotL *  BRDF_lambertian(mi.f0, mi.f90, mi.albedo, VdotH);
            f_specular += intensity * NdotL * BRDF_specularGGX(mi.f0, mi.f90, mi.alpha_roughness, VdotH, NdotL, NdotV, NdotH);
        }
    }

    vec3 f_emissive = u_emissive_factor.rgb;
#ifdef HAS_EMISSIVE_TEXTURE
    f_emissive *= texture2D(s_emissive, uv).rgb;
#endif

    vec3 color = f_emissive + f_diffuse + f_specular;

#ifdef ENABLE_SHADOW
	float visibility = shadow_visibility(v_distanceVS, vec4(v_posWS.xyz, 1.0));
	vec4 finalcolor = vec4(mix(u_shadow_color, color.rgb, visibility), basecolor.a);
#else //!ENABLE_SHADOW
	vec4 finalcolor = vec4(color, basecolor.a);
#endif //ENABLE_SHADOW

    gl_FragColor = finalcolor;
}
