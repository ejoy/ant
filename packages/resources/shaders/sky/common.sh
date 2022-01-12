#ifndef _SKY_COMMON_SH_
#define _SKY_COMMON_SH_
vec2 sampleEquirectangularMap(vec3 v)
{
    vec2 uv = vec2(atan2(v.z, v.x), asin(v.y));
    vec2 invAtan = vec2(0.1591, -0.3183);
    uv *= invAtan;
    uv += 0.5;
    return uv;
}

#endif //_SKY_COMMON_SH_