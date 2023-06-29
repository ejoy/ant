#ifndef __SHADER_LIGHTING_SH__
#define __SHADER_LIGHTING_SH__

#include "common/lightdata.sh"
#include "common/cluster_shading.sh"
#ifdef ENABLE_SHADOW
#include "common/shadow.sh"
#endif //ENABLE_SHADOW

#include "pbr/pbr.sh"
#include "pbr/material_info.sh"

#include "pbr/indirect_lighting.sh"
#include "pbr/surface_shading.sh"

// https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_lights_punctual/README.md#range-property
float get_range_attenuation(float range, float dis)
{
    return max(min(1.0 - pow(dis / range, 4.0), 1.0), 0.0) / pow(dis, 2.0);
}
// https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_lights_punctual/README.md#inner-and-outer-cone-angles
float get_spot_attenuation(vec3 pt2l, vec3 spotdir, float outter_cone, float inner_cone)
{
    float cosv = dot(normalize(spotdir), normalize(pt2l));
    return smoothstep(outter_cone, inner_cone, cosv);	//outter_cone is less than inner_cone
}

light_grid get_light_grid(vec4 fragcoord)
{
    light_grid g;
#ifdef CLUSTER_SHADING
	uint cluster_idx = which_cluster(fragcoord);

    uint cluster_count = u_cluster_size.x * u_cluster_size.y * u_cluster_size.z;
    cluster_idx = clamp(cluster_idx, 0, cluster_count-1);
	load_light_grid(b_light_grids, cluster_idx, g);
#else //!CLUSTER_SHADING
    g.offset = 0;
    g.count = u_light_count[0];
#endif //CLUSTER_SHADING
    return g;
}

uint get_light_index(uint idx)
{
#ifdef CLUSTER_SHADING
    return b_light_index_lists[idx];
#else //!CLUSTER_SHADING
    return idx;
#endif //CLUSTER_SHADING
}

void init_light_info(inout light_info l, vec3 posWS)
{
    if(IS_DIRECTIONAL_LIGHT(l.type))
    {
        l.pt2l = l.dir; //we assume l.dir is normalize
        l.attenuation = 1.0;
    }
    else
    {
        l.pt2l = l.pos - posWS;
        float pt2l_len = length(l.pt2l);
        l.attenuation = get_range_attenuation(l.range, pt2l_len);
        if (IS_SPOT_LIGHT(l.type))
        {
            l.attenuation *= get_spot_attenuation(l.pt2l, l.dir, l.outter_cutoff, l.inner_cutoff);
        }

        l.pt2l /= pt2l_len;
    }
}

light_info get_light(uint ilight, vec3 posWS)
{
    light_info l; load_light_info(b_lights, ilight, l);
    init_light_info(l, posWS);
    return l;
}

#ifdef NEW_LIGHTING
#include "pbr/surface_shading.sh"
#endif //NEW_LIGHTING

#if BGFX_SHADER_TYPE_FRAGMENT
float directional_light_visibility(in input_attributes input_attribs)
{
#   ifdef ENABLE_SHADOW
    const vec4 posWS = vec4(input_attribs.posWS + input_attribs.gN * u_normal_offset, 1.0);
	return shadow_visibility(input_attribs.distanceVS, posWS);
#   else //!ENABLE_SHADOW
    return 1.0;
#   endif //ENABLE_SHADOW
}

vec3 shading_color(in input_attributes input_attribs, in material_info mi, in uint ilight)
{
    const light_info l = get_light(0, input_attribs.posWS);
    mi.NdotL = dot(mi.N, l.pt2l);
    return mi.NdotL > 0 ? surfaceShading(mi, l) : vec3_splat(0.0);
}

#ifdef ENABLE_DEBUG_CASCADE_LEVEL
vec3 debug_cascade_level(input_attributes input_attrib)
{
    int cascadeidx = select_cascade(input_attribs.distanceVS);
    vec3 colors[4] = {
        vec3(1.0, 0.0, 0.0),
        vec3(0.0, 1.0, 0.0),
        vec3(0.0, 0.0, 1.0),
        vec3(1.0, 0.0, 1.0)
    };
    return (cascadeidx < 0) ? vec3_splat(0.0) : colors[cascadeidx];
}
#endif //ENABLE_DEBUG_CASCADE_LEVEL

vec3 calc_direct_light(in input_attributes input_attribs, in material_info mi)
{
    vec3 color = vec3_splat(0.0);
#ifdef USING_LIGHTMAP
    vec4 irradiance = texture2D(s_lightmap, input_attribs.uv1);
    color += input_attribs.basecolor.rgb * irradiance.rgb * PI * 0.5;
#else //!USING_LIGHTMAP
    const float dl_visibility = directional_light_visibility(input_attribs);
    if (dl_visibility > 0.0)
    {
        color += shading_color(input_attribs, mi, 0);
    }
#endif //USING_LIGHTMAP

#ifdef ENABLE_DEBUG_CASCADE_LEVEL
    color += debug_cascade_level(input_attrib);
#endif //ENABLE_DEBUG_CASCADE_LEVEL

    if (u_light_count[0] > 1)
    {
        //TODO: other lights not check visibility right now
        light_grid g = get_light_grid(input_attribs.fragcoord);
        for (uint ii=g.offset; ii<g.offset + g.count; ++ii)
        {
            uint ilight = get_light_index(ii);
            color += shading_color(input_attribs, mi, ilight);
        }
    }
    return color * dl_visibility;
}

vec4 compute_lighting(input_attributes input_attribs){
    material_info mi = init_material_info(input_attribs);

    vec3 color = calc_direct_light(input_attribs, mi);
#ifdef ENABLE_IBL
    vec3 indirect_light_color = calc_indirect_light(input_attribs, mi);
#ifdef ENABLE_MODULATE_INDIRECT_COLOR
    indirect_light_color *= u_indirect_modulate_color.rgb;
#endif //ENABLE_MODULATE_INDIRECT_COLOR
    color += indirect_light_color;
#endif //ENABLE_IBL
    return vec4(color, input_attribs.basecolor.a) + input_attribs.emissive;
}

#endif //BGFX_SHADER_TYPE_FRAGMENT

#endif //__SHADER_LIGHTING_SH__