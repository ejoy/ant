#ifndef __SHADER_UTILS_SH__
#define __SHADER_UTILS_SH__
#include <shaderlib.sh>

vec2 get_normalize_fragcoord(vec2 fragcoord)
{
    vec2 fg = fragcoord - u_viewRect.xy;
    return fg / u_viewRect.zw;
}

vec4 fetch_texture2d_size(sampler2D tex, int lod)
{
    ivec2 s = textureSize(tex, lod);
    return vec4(s.x, s.y, 1.0/s.x, 1.0/s.y);
}

struct gather_result3{
    vec4 r, g, b;
};

#define ENABLE_TEXTURE_GATHER

gather_result3 texture_gather3(sampler2D tex, vec2 uv)
{
    gather_result3 r;
    #ifdef ENABLE_TEXTURE_GATHER
        r.r = textureGather(tex, uv, 0);
        r.g = textureGather(tex, uv, 1);
        r.b = textureGather(tex, uv, 2);
    #else //!ENABLE_TEXTURE_GATHER
        vec3 s01 = texture2DLodOffset(tex, uv, 0.0, ivec2(0, 1)).rgb;
        vec3 s11 = texture2DLodOffset(tex, uv, 0.0, ivec2(1, 1)).rgb;
        vec3 s10 = texture2DLodOffset(tex, uv, 0.0, ivec2(1, 0)).rgb;
        vec3 s00 = texture2DLodOffset(tex, uv, 0.0, ivec2(0, 0)).rgb;

        r.r = vec4(s01.r, s11.r, s10.r, s00.r);
        r.g = vec4(s01.g, s11.g, s10.g, s00.g);
        r.b = vec4(s01.b, s11.b, s10.b, s00.b);
    #endif //ENABLE_TEXTURE_GATHER

    return r;
}

#endif //__SHADER_UTILS_SH__