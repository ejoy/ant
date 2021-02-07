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
    vec2 screen_ndc = (screen.xy / vec2(u_screen_width, u_screen_height)) * 2.0 + 1.0;
    vec4 ndc = vec4(screen_ndc, screen.zw);
    vec4 clip = mul(u_invProj, ndc);
    return clip / clip.w;
}

// dispatch as: [16, 9, 24]
NUM_THREADS(1, 1, 1)
void main(){
    //Per Tile variables
    //it same as gl_GlobalInvocationID 
    uint cluster_idx =  gl_GlobalInvocationID;

    vec2 bottomleft = gl_WorkGroupID.xy * u_tile_unit_pre_pixel;
    vec2 topright   = bottomleft + u_tile_unit_pre_pixel;

    vec4 maxPoint_sS = vec4(topright,  -1.0, 1.0);
    vec4 minPoint_sS = vec4(bottomleft,-1.0, 1.0);
    
    //Pass min and max to view space
    vec3 maxPoint_vS = screen2view(maxPoint_sS).xyz;
    vec3 minPoint_vS = screen2view(minPoint_sS).xyz;

    float nearZ = which_z(gl_WorkGroupID.z,     u_cluster_size.z);
    float farZ  = which_z(gl_WorkGroupID.z+1,   u_cluster_size.z);

    //Finding the 4 intersection points made from the maxPoint to the cluster near/far plane
    vec3 eyePos_vS    = vec3_splat(0.0);
    vec3 minPointNear = line_zplane_intersection(eyePos_vS, minPoint_vS, nearZ );
    vec3 minPointFar  = line_zplane_intersection(eyePos_vS, minPoint_vS, farZ );
    vec3 maxPointNear = line_zplane_intersection(eyePos_vS, maxPoint_vS, nearZ );
    vec3 maxPointFar  = line_zplane_intersection(eyePos_vS, maxPoint_vS, farZ );

    vec3 minPointAABB = min(min(minPointNear, minPointFar),min(maxPointNear, maxPointFar));
    vec3 maxPointAABB = max(max(minPointNear, minPointFar),max(maxPointNear, maxPointFar));

    b_cluster_AABBs[cluster_idx].minv  = vec4(minPointAABB , 0.0);
    b_cluster_AABBs[cluster_idx].maxv  = vec4(maxPointAABB , 0.0);
}