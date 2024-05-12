#include <bgfx_compute.sh>
#include "common/utils.sh"

SAMPLERCUBE(s_source, 0);
IMAGE2D_ARRAY_WO(s_result, rgba16f, 1);

uniform vec4 u_build_cubemap_mipmap_param;

#define u_lod_idx       u_build_cubemap_mipmap_param.x

NUM_THREADS(8, 8, 1)
void main()
{
    ivec3 isize = imageSize(s_result);
    if (any(gl_GlobalInvocationID.xy >= isize.xy))
        return;
    vec3 N = id2dir(gl_GlobalInvocationID, vec2(isize.xy));
    vec4 color = textureCubeLod(s_source, N, u_lod_idx);
    imageStore(s_result, ivec3(gl_GlobalInvocationID), color);
}
