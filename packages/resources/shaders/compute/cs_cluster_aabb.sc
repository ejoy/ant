#include "bgfx_shader.sh"
#include "bgfx_compute.sh"
#include "common/cluster_shading.sh"
#include "common/camera.sh"

vec3 line_zplane_intersection(vec3 A, vec3 B, float zDistance){
    vec3 plane_normal = vec3(0.0, 0.0, 1.0);
    vec3 ab =  B - A;
    //Computing the intersection length for the line and the plane
    float t = (zDistance - dot(plane_normal, A)) / dot(plane_normal, ab);
    vec3 result = A + t * ab;

    return result;
}

vec3 screen2view(vec4 screen){
    vec2 screen_ndc = (screen.xy / u_viewRect.xy);
#if !ORIGIN_BOTTOM_LEFT
    screen_ndc.y = 1.0 - screen_ndc.y;
#endif //ORIGIN_BOTTOM_LEFT

    screen_ndc = screen_ndc * 2.0 - 1.0;

    vec4 ndc = vec4(screen_ndc, screen.zw);
    vec4 clip = mul(u_invProj, ndc);
    return clip.xyz / clip.w;
}

vec3 min_vec(vec3 lhs, vec3 rhs)
{
    return vec3(
        min(lhs.x, rhs.x),
        min(lhs.y, rhs.y),
        min(lhs.z, rhs.z)
    );
}

vec3 max_vec(vec3 lhs, vec3 rhs)
{
    return vec3(
        max(lhs.x, rhs.x),
        max(lhs.y, rhs.y),
        max(lhs.z, rhs.z)
    );
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

    vec2 topleft    = gl_WorkGroupID.xy * u_tile_unit;
    vec2 topright   = topleft + vec2(u_tile_unit.x, 0.0);
    vec2 bottomleft = topleft + vec2(0.0, u_tile_unit.y);
    vec2 bottomright= topleft + u_tile_unit;

    vec3 topleft_vS     = screen2view(vec4(topleft,     near_sS, 1.0));
    vec3 topright_vS    = screen2view(vec4(topright,    near_sS, 1.0));
    vec3 bottomleft_vS  = screen2view(vec4(bottomleft,  near_sS, 1.0));
    vec3 bottomright_vS = screen2view(vec4(bottomright, near_sS, 1.0));

    float nearZ = which_z(gl_WorkGroupID.z,     u_cluster_size.z);
    float farZ  = which_z(gl_WorkGroupID.z+1,   u_cluster_size.z);

    vec3 eyepos_vS = vec3_splat(0.0);
    vec3 tln = line_zplane_intersection(eyepos_vS, topleft_vS    , nearZ);
    vec3 trn = line_zplane_intersection(eyepos_vS, topright_vS   , nearZ);
    vec3 bln = line_zplane_intersection(eyepos_vS, bottomleft_vS , nearZ);
    vec3 brn = line_zplane_intersection(eyepos_vS, bottomright_vS, nearZ);
    
    vec3 tlf = line_zplane_intersection(eyepos_vS, topleft_vS    , farZ);
    vec3 trf = line_zplane_intersection(eyepos_vS, topright_vS   , farZ);
    vec3 blf = line_zplane_intersection(eyepos_vS, bottomleft_vS , farZ);
    vec3 brf = line_zplane_intersection(eyepos_vS, bottomright_vS, farZ);

    vec3 minv = min_vec(tln, min_vec(trn, min_vec(bln, brn)));
    minv = min_vec(minv, min_vec(tlf, min_vec(trf, min_vec(blf, brf))));

    vec3 maxv = max_vec(tln, max_vec(trn, max_vec(bln, brn)));
    maxv = max_vec(maxv, max_vec(tlf, max_vec(trf, max_vec(blf, brf))));
    store_cluster_aabb2(b_cluster_AABBs, cluster_idx, vec4(minv, 0.0), vec4(maxv, 0.0));
}