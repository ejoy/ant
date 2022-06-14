#ifndef __SHADER_LIGHTING_SH__
#define __SHADER_LIGHTING_SH__

#include "common/lightdata.sh"
#include "common/cluster_shading.sh"

#include "pbr/pbr.sh"

struct material_info
{
    float roughness;      // roughness value, as authored by the model creator (input to shader)
    vec3 f0;                        // full reflectance color (n incidence angle)

    float alpha_roughness;           // roughness mapped to a more linear change in the roughness (proposed by [2])
    vec3 albedo;

    vec3 f90;                       // reflectance color at grazing angle
    float metallic;

    vec3 N;
    float NdotV;
    vec3 V;
};

float clamp_dot(vec3 x, vec3 y)
{
    return clamp(dot(x, y), 0.0, 1.0);
}

void calc_reflectance(vec3 basecolor, float metallic, out vec3 f0, out vec3 f90, out vec3 albedo)
{
    vec3 f0_ior = vec3_splat(MIN_ROUGHNESS);
    f0 = mix(f0_ior, basecolor, metallic);

    albedo = mix(basecolor * (1.0-f0_ior),  vec3_splat(0.0), metallic);
    // Compute reflectance.
    float reflectance = max(f0.r, max(f0.g, f0.b));

    // Anything less than 2% is physically impossible and is instead considered to be shadowing. Compare to "Real-Time-Rendering" 4th editon on page 325.
    f90 = vec3_splat(clamp(reflectance * 50.0, 0.0, 1.0));
}

material_info init_material_info(float metallic, float roughness, vec3 basecolor, vec3 N, vec3 V)
{
    material_info mi;

    mi.metallic = metallic;
    mi.roughness = roughness;
    // Roughness is authored as perceptual roughness; as is convention,
    // convert to material roughness by squaring the perceptual roughness.
    mi.alpha_roughness = roughness * roughness;

    mi.N = N;
    mi.V = V;
    mi.NdotV = clamp_dot(N, V);

    calc_reflectance(basecolor, metallic, mi.f0, mi.f90, mi.albedo);
    return mi;
}

// https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_lights_punctual/README.md#range-property
float get_range_attenuation(float range, float distance)
{
    return max(min(1.0 - pow(distance / range, 4.0), 1.0), 0.0) / pow(distance, 2.0);
}

// https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_lights_punctual/README.md#inner-and-outer-cone-angles
float get_spot_attenuation(vec3 pt2l, vec3 spotdir, float outter_cone, float inner_cone)
{
    float cosv = dot(normalize(spotdir), normalize(pt2l));
    return smoothstep(outter_cone, inner_cone, cosv);	//outter_cone is less than inner_cone
}

vec3 get_light_radiance(in light_info l, in vec3 posWS, in material_info mi)
{
    vec3 color = vec3_splat(0.0);
    vec3 pt2l = l.dir;
    float attenuation = 1.0;
    if(!IS_DIRECTIONAL_LIGHT(l.type))
    {
        pt2l = l.pos - posWS;
        attenuation = get_range_attenuation(l.range, length(pt2l));
        if (IS_SPOT_LIGHT(l.type))
        {
            attenuation *= get_spot_attenuation(pt2l, l.dir, l.outter_cutoff, l.inner_cutoff);
        }
    }

    vec3 intensity = attenuation * l.intensity * l.color.rgb;

    vec3 L = normalize(pt2l);
    vec3 N = mi.N;
    vec3 V = mi.V;

    vec3 H = normalize(L+V);
    float NdotL = clamp_dot(N, L);
    float NdotH = clamp_dot(N, H);
    float LdotH = clamp_dot(L, H);
    float VdotH = clamp_dot(V, H);

    if (NdotL > 0.0 || mi.NdotV > 0.0)
    {
        // Calculation of analytical light
        // https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#acknowledgments AppendixB
        color += intensity * NdotL * (
                BRDF_lambertian(mi.f0, mi.f90, mi.albedo, VdotH) +
                BRDF_specularGGX(mi.f0, mi.f90, mi.alpha_roughness, VdotH, NdotL, mi.NdotV, NdotH));
    }

    return color;
}

#if BGFX_SHADER_TYPE_FRAGMENT
vec3 calc_direct_light(in material_info mi, vec4 fragCoord, vec3 posWS)
{
    vec3 color = vec3_splat(0.0);
#ifdef CLUSTER_SHADING
	uint cluster_idx = which_cluster(fragCoord);

    uint cluster_count = u_cluster_size.x * u_cluster_size.y * u_cluster_size.z;
    cluster_idx = clamp(cluster_idx, 0, cluster_count-1);
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
        color += get_light_radiance(l, posWS, mi);
    }

#ifdef USING_LIGHTMAP
    if (u_light_count[0] > 0)
    {
        vec4 irradiance = texture2D(s_lightmap, v_texcoord1);
        color += basecolor.rgb * irradiance.rgb * PI * 0.5;
    }
#endif //USING_LIGHTMAP

    return color;
}
#endif //BGFX_SHADER_TYPE_FRAGMENT

#endif //__SHADER_LIGHTING_SH__