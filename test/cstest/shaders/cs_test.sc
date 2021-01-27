#include <bgfx_compute.sh>
IMAGE2D_WR(s_texColor, rgba8, 0);

NUM_THREADS(16, 16, 1)
void main()
{
    vec4 pixel;
    pixel.rgb = gl_GlobalInvocationID.xyz / 512.0;
    pixel.a = 1.0;
    imageStore(s_texColor, gl_GlobalInvocationID.xy, pixel);
}