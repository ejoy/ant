#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

SAMPLER2DMS(s_depth, 0);
IMAGE2D_WR(s_depth_next, d16f, 1);


NUM_THREADS(32, 32, 1)
void main()
{
    const ivec2 uv_next = gl_GlobalInvocationID.xy;

    const ivec2 s = textureSize(s_depth, 0.0);
    const ivec2 sn = textureSize(s_depth_next, 0.0);
    const vec2 uv = uv_next / vec2(sn.x, sn.y);
    
    const ivec2 uvp = floor(uv * s + 0.5);
    const float d0 = texelFetch(s_depth, uvp).r;
    const float d1 = texelFetchOffset(s_depth, uvp, 0, ivec2(1, 0)).r;
    const float d2 = texelFetchOffset(s_depth, uvp, 0, ivec2(0, 1)).r;
    const float d3 = texelFetchOffset(s_depth, uvp, 0, ivec2(1, 1)).r;

    const float d = min(min(min(d3, d2), d1), d0);
    
    imageWrite(s_depth_next, uv_next, d);
}