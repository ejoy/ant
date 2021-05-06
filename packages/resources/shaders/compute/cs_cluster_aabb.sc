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

vec3 screen2view(vec4 screen){
    vec2 screen_ndc = (screen.xy / vec2(u_screen_width, u_screen_height)) * 2.0 - 1.0;
#if ORIGIN_BOTTOM_LEFT
    screen_ndc.y = 1.0 - screen_ndc.y;
#endif //ORIGIN_BOTTOM_LEFT

    vec4 ndc = vec4(screen_ndc, screen.zw);
    vec4 clip = mul(u_invProj, ndc);
    return clip.xyz / clip.w;
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

    vec2 base = gl_WorkGroupID.xy * u_tile_unit;
    vec2 bottomleft = base + vec2(0.0, u_tile_unit.y);
    vec2 topright   = base + vec2(u_tile_unit.x, 0.0);

    vec3 min_vS = screen2view(vec4(bottomleft,  near_sS, 1.0));
    vec3 max_vS = screen2view(vec4(topright,    near_sS, 1.0));

    float nearZ = which_z(gl_WorkGroupID.z,     u_cluster_size.z);
    float farZ  = which_z(gl_WorkGroupID.z+1,   u_cluster_size.z);

    vec3 eyepos_vS = vec3_splat(0.0);
    vec3 minv = line_zplane_intersection(eyepos_vS, min_vS, nearZ);
    vec3 maxv = line_zplane_intersection(eyepos_vS, max_vS, farZ);

    store_cluster_aabb2(b_cluster_AABBs, cluster_idx, vec4(minv, 0.0), vec4(maxv, 0.0));
}