#include "bgfx_shader.sh"
#include "bgfx_compute.sh"
#include "common/cluster_shading.sh"

float sphere_closest_pt_to_aabb(vec3 center, AABB aabb){
    vec3 closest = max(aabb.minv.xyz, min(center, aabb.maxv.xyz));
    vec3 d = closest - center;
    return dot(d, d);
}

bool interset_aabb(light_info l, AABB aabb){
    float boundsphere_radius = l.range;
    vec3 center = mul(u_view, vec4(l.pos, 1.0)).xyz;
    float sq_dist = sphere_closest_pt_to_aabb(center, aabb);
    return sq_dist <= (boundsphere_radius * boundsphere_radius);
}

#define NUM_X 16
#define NUM_Y 9
#define NUM_Z 3

#define WORKGORUP_SIZE  (16 * 9 * 3)

NUM_THREADS(NUM_X, NUM_Y, NUM_Z)
void main(){
    const uint lightcount = u_culled_light_count;
    if (lightcount == 0)
        return ;
    uint cluster_idx = gl_LocalInvocationIndex + WORKGORUP_SIZE * gl_WorkGroupID.z;
    AABB aabb; load_cluster_aabb(b_cluster_AABBs, cluster_idx, aabb);

    uint visible_light_count = 0;

    //TODO: need fix!!! make a more compat b_light_index_lists buffer
    uint offset = cluster_idx * lightcount;
    uint light_idx = has_directional_light() ? 1 : 0;
    for( ; light_idx<lightcount; ++light_idx){
        light_info l; load_light_info(b_light_info_for_cull, light_idx, l);

        //TODO: need fix!!! b_light_index_lists update should use a barrier
        if(interset_aabb(l, aabb)){
            b_light_index_lists_write[offset+visible_light_count] = light_idx;
            ++visible_light_count;
            if (visible_light_count == CLUSTER_MAX_LIGHT_COUNT)
                break;
        }
    }
    store_light_grid2(b_light_grids_write, cluster_idx, offset, visible_light_count);
}