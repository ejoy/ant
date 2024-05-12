#include <bgfx_compute.sh>
#include <pbr/common.sh>
#include <pbr/direct_specular.sh>
IMAGE2D_WO(s_LUT_write, rgba16f, 0);

NUM_THREADS(8, 8, 1)
void main()
{
    ivec2 isize = imageSize(s_LUT_write);
    vec2 uv = gl_GlobalInvocationID.xy / vec2(isize);
    float dot = uv.x;
    float roughness = max(uv.y, MIN_ROUGHNESS);
    float D = LightingFuncGGX_D(dot, roughness);
    vec2 FV = LightingFuncGGX_FV(dot, roughness);

    imageStore(s_LUT_write, ivec2(gl_GlobalInvocationID.xy), vec4(D, FV.x, FV.y, 0));
}
