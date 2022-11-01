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

vec2 id2uv(ivec2 uvidx, ivec2 size)
{
    const vec2 texeloffset = vec2(0.5, 0.5);
    return ((vec2)uvidx + texeloffset)/(size-1);
}

vec2 id2uv_flipy(ivec2 uvidx, ivec2 size)
{
    vec2 uv = id2uv(uvidx, size);
    #if ORIGIN_BOTTOM_LEFT
    return uv;
#else //!ORIGIN_BOTTOM_LEFT
    return vec2(uv.x, 1.0-uv.y);
#endif //ORIGIN_BOTTOM_LEFT
}

vec3 uvface2dir(vec2 uv, int face)
{
    switch (face){
    case 0:
        return vec3( 1.0, uv.y,-uv.x);
    case 1:
        return vec3(-1.0, uv.y, uv.x);
    case 2:
        return vec3( uv.x, 1.0,-uv.y);
    case 3:
        return vec3( uv.x,-1.0, uv.y);
    case 4:
        return vec3( uv.x, uv.y, 1.0);
    default:
        return vec3(-uv.x, uv.y,-1.0);
    }
}

vec2 dir2spherecoord(vec3 v)
{
	return vec2(
		0.5f + 0.5f * atan2(v.z, v.x) / M_PI,
		acos(v.y) / M_PI);
}

// from [0, 1] ==> [-1, 1], normalize uv to symmetry uv
vec2 n2s(vec2 uv){
	return uv * 2.0 - 1.0;
}

vec3 id2dir(ivec3 id, vec2 size)
{
    vec2 uv = n2s(id2uv_flipy(id.xy, size));
    int faceidx = id.z;
    return normalize(uvface2dir(uv, faceidx));
}

struct gather_result3{
    vec4 r, g, b;
};

#define ENABLE_TEXTURE_GATHER

gather_result3 texture_gather3(sampler2DArray tex, vec3 uv)
{
    gather_result3 r;
    #ifdef ENABLE_TEXTURE_GATHER
        r.r = textureGather(tex, uv, 0);
        r.g = textureGather(tex, uv, 1);
        r.b = textureGather(tex, uv, 2);
    #else //!ENABLE_TEXTURE_GATHER
        vec3 s01 = texture2DArrayLodOffset(tex, uv, 0.0, ivec2(0, 1)).rgb;
        vec3 s11 = texture2DArrayLodOffset(tex, uv, 0.0, ivec2(1, 1)).rgb;
        vec3 s10 = texture2DArrayLodOffset(tex, uv, 0.0, ivec2(1, 0)).rgb;
        vec3 s00 = texture2DArrayLodOffset(tex, uv, 0.0, ivec2(0, 0)).rgb;

        r.r = vec4(s01.r, s11.r, s10.r, s00.r);
        r.g = vec4(s01.g, s11.g, s10.g, s00.g);
        r.b = vec4(s01.b, s11.b, s10.b, s00.b);
    #endif //ENABLE_TEXTURE_GATHER

    return r;
}

#endif //__SHADER_UTILS_SH__