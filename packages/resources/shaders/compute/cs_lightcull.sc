#include "bgfx_shader.sh"
#include "bgfx_compute.sh"
#include "common/cluster_shading.sh"

//Shared variables 
//shared light_info shared_lights[16*9*4];

float sphere_closest_pt_to_aabb(vec3 center, uint cluster_idx){
    AABB aabb = b_cluster_AABBs[cluster_idx];

    // float sqDist = 0.0;
    // for(int i = 0; i < 3; ++i){
    //     float v = pt[i];
    //     if(v < aabb.minv[i]){
    //         sqDist += (aabb.minv[i] - v) * (aabb.minv[i] - v);
    //     }
    //     if(v > aabb.maxv[i]){
    //         sqDist += (v - aabb.maxv[i]) * (v - aabb.maxv[i]);
    //     }
    // }
    // return sqDist;

    vec3 closest = max(aabb.minv.xyz, min(center, aabb.maxv.xyz));
    vec3 d = closest - center;
    return dot(d, d);
    // var x = Math.max(box.minX, Math.min(sphere.x, box.maxX));
    // var y = Math.max(box.minY, Math.min(sphere.y, box.maxY));
    // var z = Math.max(box.minZ, Math.min(sphere.z, box.maxZ));

    // var distance = Math.sqrt((x - sphere.x) * (x - sphere.x) +
    //                         (y - sphere.y) * (y - sphere.y) +
    //                         (z - sphere.z) * (z - sphere.z));

    //return distance < sphere.radius;
}

bool interset_aabb(light_info l, uint cluster_idx){
    float boundsphere_radius = l.range;
    vec3 center = mul(u_view, vec4(l.pos, 1.0)).xyz;
    float sq_dist = sphere_closest_pt_to_aabb(center, cluster_idx);
    return sq_dist <= (boundsphere_radius * boundsphere_radius);
}

#if BGFX_SHADER_LANGUAGE_HLSL
uint buffer_length(StructuredBuffer<light_info> bo)
{
    uint num, stride;
    bo.GetDimensions(num, stride);
    return num;
}
#else
uint buffer_length(StructuredBuffer<light_info> bo){
    return bo.length();
}
#endif

// cluster num: 16 * 9 * 24, dispatch(1, 1, 6)
// NUM_THREADS(16, 9, 4)
// void main(){
//     b_global_index_count[0] = 0;
//     uint thread_count = gl_WorkGroupSize.x * gl_WorkGroupSize.y * gl_WorkGroupSize.z;
//     uint light_count  = buffer_length(b_lights);
//     uint num_batches = (light_count + thread_count -1) / thread_count;

//     uint cluster_idx = gl_LocalInvocationIndex + gl_WorkGroupSize.x * gl_WorkGroupSize.y * gl_WorkGroupSize.z * gl_WorkGroupID.z;
    
//     uint visible_light_count = 0;
//     uint visible_light_indices[100];

//     for( uint batch = 0; batch < num_batches; ++batch){
//         uint light_idx = batch * thread_count + gl_LocalInvocationIndex;

//         //Prevent overflow by clamping to last light which is always null
//         light_idx = min(light_idx, light_count);

//         //Populating shared light array
//         shared_lights[gl_LocalInvocationIndex] = b_lights[light_idx];
//         barrier();

//         //Iterating within the current batch of lights
//         for( uint light = 0; light < thread_count; ++light){
//             if( shared_lights[light].enabled  == 1){
//                 if( interset_aabb(light, cluster_idx) ){
//                     visible_light_indices[visible_light_count] = batch * thread_count + light;
//                     visible_light_count += 1;
//                 }
//             }
//         }
//     }

//     //We want all thread groups to have completed the light tests before continuing
//     barrier();

//     uint offset = atomicAdd(b_global_index_count[0], visible_light_count);

//     for(uint i = 0; i < visible_light_count; ++i){
//         b_light_index_lists[offset + i] = visible_light_indices[i];
//     }

//     b_light_grids[cluster_idx].offset = offset;
//     b_light_grids[cluster_idx].count = visible_light_count;
// }


NUM_THREADS(16, 9, 4)
void main(){
    uint light_count  = buffer_length(b_lights);
    uint workgroup_size = 16 * 9 * 4;
    uint cluster_idx = gl_LocalInvocationIndex + workgroup_size * gl_WorkGroupID.z;
    
    uint visible_light_count = 0;
    uint visible_light_indices[100];

    for(uint light_idx=0; light_idx<light_count; ++light_idx){
        light_info l = b_lights[light_idx];
        //if(l.enable == 1) {
            if(interset_aabb(l, cluster_idx)){
                visible_light_indices[visible_light_count] = light_idx;
                ++visible_light_count;
            }
        //}
    }

    //TODO: if we can init this value before call compute dispatch, we can remove barrier() call
    b_global_index_count[0] = 0;
    // need init b_global_index_count before modify
    barrier();
    uint offset;
    atomicFetchAndAdd(b_global_index_count[0], visible_light_count, offset);

    for(uint i = 0; i < visible_light_count; ++i){
        b_light_index_lists[offset + i] = visible_light_indices[i];
    }

    b_light_grids[cluster_idx].offset = offset;
    b_light_grids[cluster_idx].count = visible_light_count;
}