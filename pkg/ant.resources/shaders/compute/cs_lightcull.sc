#include "bgfx_shader.sh"
#include "bgfx_compute.sh"
#include "common/cluster_shading.sh"

float sphere_closest_pt_to_aabb(vec3 center, AABB aabb){
    vec3 closest = max(aabb.minv.xyz, min(center, aabb.maxv.xyz));
    vec3 d = closest - center;
    return dot(d, d);
}

vec3 aabb_center(AABB aabb){
    return 0.5 * (aabb.minv + aabb.maxv);
}

// https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_lights_punctual/README.md#range-property
float get_range_attenuation(float range, float dis)
{
    return saturate(1.0 - pow(dis / range, 4.0)) / (dis*dis);
}
// https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_lights_punctual/README.md#inner-and-outer-cone-angles
float get_spot_attenuation(vec3 pt2l, vec3 spotdir, float outter_cone, float inner_cone)
{
    float cosv = dot(normalize(spotdir), normalize(pt2l));
    return smoothstep(outter_cone, inner_cone, cosv);	//outter_cone is less than inner_cone
}

float get_light_attenuation(light_info l, AABB aabb){
    const vec3 clustercenter = aabb_center(aabb);

    const vec3 pt2l = clustercenter - l.pos;   //l.pos in viewspace
    const float dis = length(pt2l);
    const float attenuation = get_range_attenuation(l.range, dis);
    if (IS_SPOT_LIGHT(l.type))
    {
        return attenuation * get_spot_attenuation(pt2l, l.dir, l.outter_cutoff, l.inner_cutoff);
    }

    return attenuation;
}

#define LIGHT_ATTENUATION_THRESHOLD 0.008
bool check_light_valid(light_info l, AABB aabb){
    const float attenuation = get_light_attenuation(l, aabb);
    return (l.intensity * attenuation) > LIGHT_ATTENUATION_THRESHOLD;
}

bool check_light_interset_aabb(light_info l, AABB aabb, uint clusterlightcount){
    //TODO: if cluster have enough lights, we should sort the lights, and remove light which intensity is lowest
    const uint halfcount = uint(u_cluster_max_light_count * 0.3);
    if (clusterlightcount < halfcount || check_light_valid(l, aabb)){
        const float sq_dist = sphere_closest_pt_to_aabb(l.pos, aabb);
        return sq_dist <= (l.range * l.range);
    }
    return false;
}

void transform_light(inout light_info l){
    l.pos = mul(u_view, vec4(l.pos, 1.0)).xyz;
}

uint light_offset_idx()
{
    return u_all_light_count - u_culled_light_count;
}

//b_light_index_lists_write/b_light_index_lists used to keep which lights are visible right now.
//it's a array<uint, num_clusters*u_cluster_max_light_count> buffer, so each cluster will occpy u_cluster_max_light_count uint buffer
//I did not found any dynamic method to keep this buffer more compat


//TODO: use shared data to transform all the light pos from worldspace to viewspace, to save ALU time
NUM_THREADS(THREAD_NUM_X, THREAD_NUM_Y, THREAD_NUM_Z)
void main(){
    if (u_culled_light_count == 0)
        return ;

    const uint cluster_idx = cluster_index(gl_WorkGroupID, uvec3(THREAD_NUM_X, THREAD_NUM_Y, THREAD_NUM_Z), gl_LocalInvocationIndex);

    AABB aabb; load_cluster_aabb(b_cluster_AABBs, cluster_idx, aabb);

    const uint offset = cluster_idx * u_cluster_max_light_count;
    uint visible_light_count = 0;

    for(uint light_idx = light_offset_idx(); light_idx<u_all_light_count; ++light_idx){
        light_info l = (light_info)0; load_light_info(b_light_info_for_cull, light_idx, l);
        transform_light(l);
        if(check_light_interset_aabb(l, aabb, visible_light_count)){
            b_light_index_lists_write[offset+visible_light_count++] = light_idx;
            if (visible_light_count == u_cluster_max_light_count)
                break;
        }
    }
    store_light_grid2(b_light_grids_write, cluster_idx, offset, visible_light_count);
}