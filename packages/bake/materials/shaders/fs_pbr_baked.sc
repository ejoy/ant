$input v_texcoord0, v_normal, v_tangent, v_bitangent, v_posWS

#include <bgfx_shader.sh>
#include <bgfx_compute.sh>
#include <shaderlib.sh>
#include "common/lighting.sh"
#include "common/transform.sh"
#include "common/utils.sh"
#include "common/cluster_shading.sh"
#include "pbr/pbr.sh"

// material properites
SAMPLER2D(s_basecolor,          0);
SAMPLER2D(s_metallic_roughness, 1);
SAMPLER2D(s_normal,             2);
SAMPLER2D(s_emissive,           3);
SAMPLER2D(s_occlusion,          4);

//SAMPLER2D(s_lightmap,           8);

uniform vec4 u_basecolor_factor;
uniform vec4 u_emissive_factor;
uniform vec4 u_pbr_factor;
#define u_metallic_factor    u_pbr_factor.x
#define u_roughness_factor   u_pbr_factor.y
#define u_alpha_mask_cutoff  u_pbr_factor.z
#define u_occlusion_strength u_pbr_factor.w

struct material_info
{
    float roughness;      // roughness value, as authored by the model creator (input to shader)
    vec3 f0;                        // full reflectance color (n incidence angle)

    float alpha_roughness;           // roughness mapped to a more linear change in the roughness (proposed by [2])
    vec3 albedo;

    vec3 f90;                       // reflectance color at grazing angle
    float metallic;
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

float clamp_dot(vec3 x, vec3 y)
{
    return clamp(dot(x, y), 0.0, 1.0);
}

material_info get_material_info(vec4 basecolor, vec2 uv)
{
    material_info mi;
    get_metallic_roughness(mi.metallic, mi.roughness, uv);
    // Roughness is authored as perceptual roughness; as is convention,
    // convert to material roughness by squaring the perceptual roughness.
    mi.alpha_roughness = mi.roughness * mi.roughness;

    // Achromatic f0 based on IOR.
    vec3 f0_ior = vec3_splat(MIN_ROUGHNESS);
    mi.albedo = mix(basecolor.rgb * (1.0 - f0_ior),  vec3_splat(0.0), mi.metallic);
    mi.f0 = mix(f0_ior, basecolor.rgb, mi.metallic);
    // Compute reflectance.
    float reflectance = max(mi.f0.r, max(mi.f0.g, mi.f0.b));

    // Anything less than 2% is physically impossible and is instead considered to be shadowing. Compare to "Real-Time-Rendering" 4th editon on page 325.
    mi.f90 = vec3_splat(clamp(reflectance * 50.0, 0.0, 1.0));
    return mi;
}

vec3 BRDF_lambertian_baked(vec3 diffuseColor)
{
    // see https://seblagarde.wordpress.com/2012/01/08/pi-or-not-to-pi-in-game-lighting-equation/
    return (diffuseColor / M_PI);
}

void main()
{
    vec2 uv = v_texcoord0;
    vec4 basecolor = get_basecolor(uv);

#ifdef ALPHAMODE_OPAQUE
    basecolor.a = u_alpha_mask_cutoff;
#endif

#ifdef ALPHAMODE_MASK
    // Late discard to avoid samplig artifacts. See https://github.com/KhronosGroup/glTF-Sample-Viewer/issues/267
    if(basecolor.a < u_alpha_mask_cutoff)
    {
        discard;
    }
    basecolor.a = 1.0;
#endif

#ifdef MATERIAL_UNLIT
    gl_FragColor = basecolor;
    return;
#endif
    vec3 N = get_normal(v_tangent, v_bitangent, v_normal, uv);

    material_info mi = get_material_info(basecolor, uv);

    // LIGHTING
    vec3 color = vec3_splat(0.0);

#ifdef HAS_OCCLUSION_TEXTURE
    float ao = texture2D(s_occlusion,  uv).r;
    color  += mix(f_diffuse, f_diffuse * ao, u_occlusion_strength) + 
            = mix(f_specular, f_specular * ao, u_occlusion_strength);
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
        float NdotL = clamp_dot(N, L);
        color += intensity * NdotL * BRDF_lambertian_baked(mi.albedo);
    }

#ifdef HAS_EMISSIVE_TEXTURE
    color += texture2D(s_emissive, uv).rgb * u_emissive_factor.rgb;
#endif
    gl_FragColor = vec4(color, basecolor.a);
}
