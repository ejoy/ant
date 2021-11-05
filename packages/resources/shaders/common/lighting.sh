#ifndef __SHADER_LIGHTING_SH__
#define __SHADER_LIGHTING_SH__

uniform vec4 u_light_count;

struct light_info{
	vec3	pos;
	float	range;
	vec3	dir;
	float	enable;
	vec4	color;
	float	type;
	float	intensity;
	float	inner_cutoff;
	float	outter_cutoff;
};

#define LightType_Directional 0
#define LightType_Point 1
#define LightType_Spot 2

#define IS_DIRECTIONAL_LIGHT(_type) (_type==LightType_Directional)
#define IS_POINT_LIGHT(_type)       (_type==LightType_Point)
#define IS_SPOT_LIGHT(_type)        (_type==LightType_Spot)

struct material_info
{
    float roughness;      // roughness value, as authored by the model creator (input to shader)
    vec3 f0;                        // full reflectance color (n incidence angle)

    float alpha_roughness;           // roughness mapped to a more linear change in the roughness (proposed by [2])
    vec3 albedo;

    vec3 f90;                       // reflectance color at grazing angle
    float metallic;
};


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

#include "pbr.sh"

void calc_reflectance(vec3 f0_ior, vec4 basecolor, inout material_info mi)
{
    mi.f0 = mix(f0_ior, basecolor.rgb, mi.metallic);
    // Compute reflectance.
    float reflectance = max(mi.f0.r, max(mi.f0.g, mi.f0.b));

    // Anything less than 2% is physically impossible and is instead considered to be shadowing. Compare to "Real-Time-Rendering" 4th editon on page 325.
    mi.f90 = vec3_splat(clamp(reflectance * 50.0, 0.0, 1.0));
}

vec3 get_light_radiance(light_info l, vec3 posWS, vec3 N, vec3 V, float NdotV, material_info mi)
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
    vec3 H = normalize(L+V);
    float NdotL = clamp_dot(N, L);
    float NdotH = clamp_dot(N, H);
    float LdotH = clamp_dot(L, H);
    float VdotH = clamp_dot(V, H);

    if (NdotL > 0.0 || NdotV > 0.0)
    {
        // Calculation of analytical light
        // https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#acknowledgments AppendixB
        color += intensity * NdotL * (
                BRDF_lambertian(mi.f0, mi.f90, mi.albedo, VdotH) +
                BRDF_specularGGX(mi.f0, mi.f90, mi.alpha_roughness, VdotH, NdotL, NdotV, NdotH));
    }

    return color;
}

#endif //__SHADER_LIGHTING_SH__