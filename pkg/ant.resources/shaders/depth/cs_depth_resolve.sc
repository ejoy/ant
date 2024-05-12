#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

#ifndef MSAA_COUNT
#define MSAA_COUNT 4
#endif //MSAA_COUNT

SAMPLER2DMS(s_depthMSAA, 0);
IMAGE2D_WO(s_depth, r16f, 1);

NUM_THREADS(16, 16, 1)
void main()
{
    const ivec2 uv = gl_GlobalInvocationID.xy;
    const ivec2 s = imageSize(s_depth);
    if (all(uv < s)){
        float depth = 1.0;
        for (int ii=0; ii<MSAA_COUNT; ++ii)
        {
            float d = texelFetch(s_depthMSAA, uv, ii).r;
            depth = min(depth, d);
        }
        
        imageStore(s_depth, uv, depth);
    }
}