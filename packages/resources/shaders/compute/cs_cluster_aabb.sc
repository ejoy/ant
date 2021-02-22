#include "bgfx_shader.sh"
#include "bgfx_compute.sh"
#include "common/cluster_shading.sh"

vec3 line_zplane_intersection(vec3 A, vec3 B, float zDistance){
    vec3 plane_normal = vec3(0.0, 0.0, 1.0);
    vec3 ab =  B - A;
    //Computing the intersection length for the line and the plane
    float t = (zDistance - dot(plane_normal, A)) / dot(plane_normal, ab);
    vec3 result = A + t * ab;

    return result;
}

vec4 screen2view(vec4 screen){
    vec2 screen_ndc = (screen.xy / vec2(u_screen_width, u_screen_height)) * 2.0 - 1.0;
#if ORIGIN_TOP_LEFT
    screen_ndc.y = 1.0 - screen_ndc.y;
#endif //ORIGIN_TOP_LEFT

    vec4 ndc = vec4(screen_ndc, screen.zw);
    vec4 clip = mul(u_invProj, ndc);
    return clip / clip.w;
}

// dispatch as: [16, 9, 24]
NUM_THREADS(1, 1, 1)
void main(){
    uint cluster_idx = dot(gl_WorkGroupID, uvec3(1, u_cluster_size.x, u_cluster_size.x * u_cluster_size.y));

#if HOMOGENEOUS_DEPTH
    float near_sS = -1.0;
#else //!HOMOGENEOUS_DEPTH
    float near_sS = 0.0;
#endif //HOMOGENEOUS_DEPTH

#if ORIGIN_TOP_LEFT
    vec2 topleft = gl_WorkGroupID.xy * u_tile_unit_pre_pixel;
    vec2 bottomright = topleft + u_tile_unit_pre_pixel;

    vec4 min_sS = vec4(topleft,     near_sS, 1.0);
    vec4 max_sS = vec4(bottomright, near_sS, 1.0);
#else //!ORIGIN_TOP_LEFT
    vec2 bottomleft = gl_WorkGroupID.xy * u_tile_unit_pre_pixel;
    vec2 topright = bottomleft + u_tile_unit_pre_pixel;

    vec4 min_sS = vec4(bottomleft,near_sS, 1.0);
    vec4 max_sS = vec4(topright,  near_sS, 1.0);
#endif //ORIGIN_TOP_LEFT

    vec3 max_vS = screen2view(max_sS).xyz;
    vec3 min_vS = screen2view(min_sS).xyz;

    float nearZ = which_z(gl_WorkGroupID.z,     u_cluster_size.z);
    float farZ  = which_z(gl_WorkGroupID.z+1,   u_cluster_size.z);

    vec3 eyepos_vS   = vec3_splat(0.0);
    vec3 min_near_vS = line_zplane_intersection(eyepos_vS, min_vS, nearZ);
    vec3 min_far_vS  = line_zplane_intersection(eyepos_vS, min_vS, farZ);
    vec3 max_near_vS = line_zplane_intersection(eyepos_vS, max_vS, nearZ);
    vec3 max_far_vS  = line_zplane_intersection(eyepos_vS, max_vS, farZ);

    vec3 minv = min(min(min_near_vS, min_far_vS),min(max_near_vS, max_far_vS));
    vec3 maxv = max(max(min_near_vS, min_far_vS),max(max_near_vS, max_far_vS));

    store_cluster_aabb2(b_cluster_AABBs, cluster_idx, vec4(minv, 0.0), vec4(maxv, 0.0));
}