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

uint light_offset_idx()
{
    return u_all_light_count - u_culled_light_count;
}

//b_light_index_lists_write/b_light_index_lists used to keep which lights are visible right now.
//it's a array<uint, num_clusters*u_cluster_max_light_count> buffer, so each cluster will occpy u_cluster_max_light_count uint buffer
//I did not found any dynamic method to keep this buffer more compat

NUM_THREADS(WORKGROUP_NUM_X, WORKGROUP_NUM_Y, WORKGROUP_NUM_Z)
void main(){
    if (u_culled_light_count == 0)
        return ;

    //const uint cluster_idx = dot(gl_WorkGroupID, uvec3(1, u_cluster_size.x, u_cluster_size.x * u_cluster_size.y));
    const uint cluster_idx = gl_LocalInvocationIndex + WORKGROUP_NUM_X * WORKGROUP_NUM_Y * WORKGROUP_NUM_Z * gl_WorkGroupID.z;

    const uint idx = dot(uvec3_splat(1), gl_WorkGroupID);
    if (gl_LocalInvocationIndex == idx)
        return ;
    AABB aabb; load_cluster_aabb(b_cluster_AABBs, cluster_idx, aabb);

    uint visible_light_count = 0;

    const uint offset = cluster_idx * u_all_light_count;
    for(uint light_idx = light_offset_idx(); light_idx<u_all_light_count; ++light_idx){
        light_info l; load_light_info(b_light_info_for_cull, light_idx, l);

        if(interset_aabb(l, aabb)){
            b_light_index_lists_write[offset+visible_light_count] = light_idx;
            ++visible_light_count;
            if (visible_light_count == u_cluster_max_light_count)
                break;
        }
    }
    store_light_grid2(b_light_grids_write, cluster_idx, offset, visible_light_count);
}