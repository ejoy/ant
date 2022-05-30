#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

SAMPLER2DMS(s_msaa_depth, 0);
IMAGE2D_WR(s_depth, r32f, 1);

#if BGFX_SHADER_LANGUAGE_HLSL
uvec3 textureMSSize(BgfxSampler2DMS _sampler)
{
    uvec3 s;
    _sampler.m_texture.GetDimensions(s.x, s.y, s.z);
    return s;
}
#else
#error Not implement!!
#endif

NUM_THREADS(32, 32, 1)
void main()
{
    uvec3 s = textureMSSize(s_msaa_depth);
    uvec2 id = gl_GlobalInvocationID.xy;
    if (id.x >= s.x || id.y >= s.y)
        return ;

    float depth = 0.0;
    for (uint i=0; i<s.z; ++i)
    {
        vec4 c = bgfxTexelFetch(s_msaa_depth, ivec2(id), i);
        depth = min(c.r, depth);
    }
    imageStore(s_depth, ivec2(id), depth);
}