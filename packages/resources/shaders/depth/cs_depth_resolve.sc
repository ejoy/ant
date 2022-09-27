#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

#ifndef MSAA_COUNT
#define MSAA_COUNT 4
#endif //MSAA_COUNT

SAMPLER2DMS(s_depthMSAA, 0);
IMAGE2D_WR(s_depth, d16f, 1);

NUM_THREADS(32, 32, 1)
void main()
{
    ivec2 uv = gl_GlobalInvocationID.xy;
    float depth = 1.0;
    for (int ii=0; ii<MSAA_COUNT; ++ii)
    {
        float d = texelFetch(s_depthMSAA, uv, ii).r;
        depth = min(depth, d);
    }
    
    imageWrite(s_depth, uv, depth);
}