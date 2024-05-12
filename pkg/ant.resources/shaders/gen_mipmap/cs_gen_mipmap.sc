#include <bgfx_compute.sh>

SAMPLER2D(s_source, 0);
IMAGE2D_ARRAY_WO(s_result_source, rgba16f, 1);

uniform vec4 u_param;

#define u_lod_idx       u_param.x
#define u_image_width   u_param.y
#define u_image_height  u_param.z

NUM_THREADS(8, 8, 1)
void main()
{
    ivec2 isize = imageSize(s_result_source);
    vec2 uv = vec2(gl_GlobalInvocationID.xy) / isize; //vec2(u_image_width, u_image_height);
    vec4 color = texture2DLod(s_source, uv, u_lod_idx);
    imageStore(s_result_source, ivec3(gl_GlobalInvocationID), color);
}
