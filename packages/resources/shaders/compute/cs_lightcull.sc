#include "bgfx_shader.sh"
#include "bgfx_compute.sh"
#include "common/cluster_shading.sh"
#include "common/lighting.sh"

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

NUM_THREADS(16, 9, 4)
void main(){
    uint light_count = u_light_count.x;
    uint workgroup_size = 16 * 9 * 4;
    uint cluster_idx = gl_LocalInvocationIndex + workgroup_size * gl_WorkGroupID.z;
    AABB aabb; load_cluster_aabb(b_cluster_AABBs, cluster_idx, aabb);

    uint visible_light_count = 0;

    uint offset = cluster_idx * light_count;
    for(uint light_idx=0; light_idx<light_count; ++light_idx){
        light_info l; load_light_info(b_lights, light_idx, l);

        if(interset_aabb(l, aabb)){
            b_light_index_lists[offset+visible_light_count] = light_idx;
            ++visible_light_count;
        }
    }
    store_light_grid2(b_light_grids, cluster_idx, offset, visible_light_count);
}