
#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

#include "common/utils.sh"
#include "pbr/ibl/common.sh"

IMAGE2D_RO(s_color_input,  rgba32f, 0);
IMAGE2D_WO(s_color_output, rgba32f, 1);

NUM_THREADS(WORKGROUP_THREADS, WORKGROUP_THREADS, 1)
void main()
{
    if (ivec2(u_facesize, u_facesize) <= gl_GlobalInvocationID.xy)
        return ;

    const int lod = (int)u_lod;
    const ivec2 uv = gl_GlobalInvocationID.xy;
    const int face = gl_GlobalInvocationID.z;
    const ivec2 input_uv = ivec2(uv.x*2, uv.y+face*u_facesize);

    for (int ii=0; ii<IRRADIANCE_SH_COEFF_NUM; ++ii)
    {
        const ivec2 uv00 = ivec2((input_uv.x*IRRADIANCE_SH_COEFF_NUM)    +ii, input_uv.y);
        const ivec2 uv10 = ivec2(((input_uv.x+1)*IRRADIANCE_SH_COEFF_NUM)+ii, input_uv.y);
        const ivec2 uv01 = ivec2((input_uv.x*IRRADIANCE_SH_COEFF_NUM)    +ii, input_uv.y+1);
        const ivec2 uv11 = ivec2(((input_uv.x+1)*IRRADIANCE_SH_COEFF_NUM)+ii, input_uv.y+1);

        const vec3 v00 = imageLoad(s_color_input, uv00);
        const vec3 v10 = imageLoad(s_color_input, uv10);
        const vec3 v01 = imageLoad(s_color_input, uv01);
        const vec3 v11 = imageLoad(s_color_input, uv11);

        const vec3 finalresult = v00+v10+v01+v11;

        const ivec2 uv_out = ivec2(uv.x*IRRADIANCE_SH_COEFF_NUM+ii, uv.y);
        imageStore(s_color_output, ivec3(uv_out, face), finalresult);
    }
}