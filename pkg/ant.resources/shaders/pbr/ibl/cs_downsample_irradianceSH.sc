
#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

#include "common/utils.sh"
#include "pbr/ibl/common.sh"

SAMPLER2D(s_color_input, 0);
IMAGE2D_WR(s_color_output, rgba32f, 1);

uniform vec4 u_SH_param;
#define u_facesize  u_SH_param.x
#define u_lod       u_SH_param.y

NUM_THREADS(16, 16, 1)
void main()
{
    const int lod = (int)u_lod;
    const vec2 uv = gl_GlobalInvocationID.xy;

    for (int ii=0; ii<IRRADIANCE_SH_COEFF_NUM; ++ii)
    {
        vec3 c = texture2DLod(s_color_input, uv, lod).rgb;
        imageStore(s_color_output, uv_out, finalresult);
    }
}