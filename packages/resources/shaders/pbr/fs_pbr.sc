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
#define u_metallic_factor   u_pbr_factor.x
#define u_roughness_factor  u_pbr_factor.y
#define u_alpha_mask        u_pbr_factor.x
#define u_alpha_mask_cutoff u_pbr_factor.y

uniform vec4 u_pbr_factor2;
#define u_occlusion_strength u_pbr_factor2.x
#define u_ibl_prefilter_mipmap_count u_pbr_factor2.y

struct MaterialInfo
{
    float perceptualRoughness;      // roughness value, as authored by the model creator (input to shader)
    vec3 f0;                        // full reflectance color (n incidence angle)

    float alphaRoughness;           // roughness mapped to a more linear change in the roughness (proposed by [2])
    vec3 albedoColor;

    vec3 f90;                       // reflectance color at grazing angle
    float metallic;

    vec3 n;
    vec3 basecolor;
};

vec4 get_basecolor(vec2 texcoord)
{
    #ifdef HAS_BASECOLOR_MAP_TEXTURE
        return u_basecolor_factor * texture(s_basecolor, texcoord);
    #else
        return u_basecolor_factor;
    #endif
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


MaterialInfo getMetallicRoughnessInfo(MaterialInfo info, float f0_ior)
{
    info.metallic = u_MetallicFactor;
    info.perceptualRoughness = u_RoughnessFactor;

#ifdef HAS_METALLIC_ROUGHNESS_TEXTURE
    // Roughness is stored in the 'g' channel, metallic is stored in the 'b' channel.
    // This layout intentionally reserves the 'r' channel for (optional) occlusion map data
    vec4 mrSample = texture(u_MetallicRoughnessSampler, getMetallicRoughnessUV());
    info.perceptualRoughness *= mrSample.g;
    info.metallic *= mrSample.b;
#endif

    // Achromatic f0 based on IOR.
    info.albedoColor = mix(info.basecolor.rgb * (1.0 - f0_ior),  vec3_splat(0.0), info.metallic);
    info.f0 = mix(vec3_splat(f0_ior), info.basecolor.rgb, info.metallic);

    return info;
}

float clamp_dot(vec3 x, vec3 y)
{
    return clamp(dot(x, y), 0.0, 1.0);
}

vec3 getIBLRadianceLambertian(vec3 n, vec3 diffuseColor)
{
    return textureCube(s_irradiance, n).rgb * diffuseColor;
}

vec3 getIBLRadianceGGX(vec3 n, vec3 v, float NdotV, float perceptualRoughness, vec3 specularColor)
{
    float lod = clamp(perceptualRoughness * u_ibl_prefilter_mipmap_count, 0.0, u_ibl_prefilter_mipmap_count);
    vec3 reflection = normalize(reflect(-v, n));

    vec2 brdfSamplePoint = clamp(vec2(NdotV, perceptualRoughness), vec2(0.0, 0.0), vec2(1.0, 1.0));
    vec2 brdf = texture(s_LUT, brdfSamplePoint).rg;
    vec3 specularLight = textureCubeLod(s_prefilter, reflection, lod).rgb;
   return specularLight * (specularColor * brdf.x + brdf.y);
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
    basecolor.a = u_alpha_mask;
#endif

#ifdef ALPHAMODE_MASK
    // Late discard to avaoid samplig artifacts. See https://github.com/KhronosGroup/glTF-Sample-Viewer/issues/267
    if(basecolor.a < u_alpha_mask_cutoff)
    {
        discard;
    }
    basecolor.a = 1.0;
#endif

    vec3 v = normalize(u_eyepos - v_posWS.xyz);
    vec3 n = get_normal(v_tangent, v_bitangent, v_normal, uv);
    float NdotV = clamp_dot(n, v);

    MaterialInfo materialInfo;
    materialInfo.basecolor  = basecolor.rgb;
    materialInfo            = getMetallicRoughnessInfo(materialInfo, MIN_ROUGHNESS);
    materialInfo.perceptualRoughness = clamp(materialInfo.perceptualRoughness, 0.0, 1.0);
    materialInfo.metallic   = clamp(materialInfo.metallic, 0.0, 1.0);

    // Roughness is authored as perceptual roughness; as is convention,
    // convert to material roughness by squaring the perceptual roughness.
    materialInfo.alphaRoughness = materialInfo.perceptualRoughness * materialInfo.perceptualRoughness;

    // Compute reflectance.
    float reflectance = max(max(materialInfo.f0.r, materialInfo.f0.g), materialInfo.f0.b);

    // Anything less than 2% is physically impossible and is instead considered to be shadowing. Compare to "Real-Time-Rendering" 4th editon on page 325.
    materialInfo.f90 = vec3(clamp(reflectance * 50.0, 0.0, 1.0));

    materialInfo.n = n;

    // LIGHTING
    vec3 f_specular = vec3_splat(0.0);
    vec3 f_diffuse = vec3_splat(0.0);

    float NdotV = clamp_dot(n, v);

    // Calculate lighting contribution from image based lighting source (IBL)
#ifdef USE_IBL
    f_specular += getIBLRadianceGGX(NdotV, materialInfo.perceptualRoughness, materialInfo.f0);
    f_diffuse += getIBLRadianceLambertian(n, materialInfo.albedoColor);
#endif

#ifdef HAS_OCCLUSION_TEXTURE
    float ao = texture(s_occlusion,  uv).r;
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

        vec3 pointToLight = l.dir;
        float rangeAttenuation = 1.0;
        float spotAttenuation = 1.0;

        if(!IS_DIRECTIONAL_LIGHT(l.type))
        {
            pointToLight = l.pos - v_posWS.xyz;
            rangeAttenuation = getRangeAttenuation(l.range, length(pointToLight));
            if (IS_SPOT_LIGHT(l.type))
            {
                spotAttenuation = getSpotAttenuation(pointToLight, l.dir, l.outter_cutoff, l.inner_cutoff);
            }
        }

        vec3 intensity = rangeAttenuation * spotAttenuation * light.intensity * light.color;

        vec3 l = normalize(pointToLight);   // Direction from surface point to light
        vec3 h = normalize(l + v);          // Direction of the vector between l and v, called halfway vector
        float NdotL = clamp_dot(n, l);
        float NdotH = clamp_dot(n, h);
        float LdotH = clamp_dot(l, h);
        float VdotH = clamp_dot(v, h);

        if (NdotL > 0.0 || NdotV > 0.0)
        {
            // Calculation of analytical light
            // https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#acknowledgments AppendixB
            f_diffuse += intensity * NdotL *  BRDF_lambertian(materialInfo.f0, materialInfo.f90, materialInfo.albedoColor, VdotH);
            f_specular += intensity * NdotL * BRDF_specularGGX(materialInfo.f0, materialInfo.f90, materialInfo.alphaRoughness, VdotH, NdotL, NdotV, NdotH);
        }
    }
#endif // !USE_PUNCTUAL

    vec3 f_emissive = u_emissive_factor.rgb;
#ifdef HAS_EMISSIVE_TEXTURE
    f_emissive *= texture(s_emissive, uv).rgb;
#endif

    vec3 color = f_emissive + diffuse + f_specular;
    gl_FragColor = vec4(color.rgb, basecolor.a);
}
