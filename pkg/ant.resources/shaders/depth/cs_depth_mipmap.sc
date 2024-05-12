#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

IMAGE2D_RO(s_depth, r16f, 0);
IMAGE2D_WO(s_depth_next, r16f, 1);

NUM_THREADS(16, 16, 1)
void main()
{
    const ivec2 uv_next = gl_GlobalInvocationID.xy;
    const ivec2 sn = imageSize(s_depth_next);
    if (all(uv_next < sn)){
        const ivec2 s = imageSize(s_depth);
        
        const vec2 uv = uv_next / vec2(sn.x, sn.y);
        
        const ivec2 uvp = floor(uv * s + 0.5);
        //TODO: textureGather ??
        const float d0 = imageLoad(s_depth, uvp).r;
        const float d1 = imageLoad(s_depth, uvp + ivec2(1, 0)).r;
        const float d2 = imageLoad(s_depth, uvp + ivec2(0, 1)).r;
        const float d3 = imageLoad(s_depth, uvp + ivec2(1, 1)).r;

        const float d = min(min(min(d3, d2), d1), d0);
        
        imageStore(s_depth_next, uv_next, d);
    }
}