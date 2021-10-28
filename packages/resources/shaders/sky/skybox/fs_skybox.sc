$input v_posWS

#include <bgfx_shader.sh>

#ifdef CUBEMAP_SKY
SAMPLERCUBE(s_skybox, 0);
#else //!CUBEMAP_SKY
SAMPLER2D(s_skybox, 0);
#endif //CUBEMAP_SKY

#ifndef CUBEMAP_SKY

vec2 sampleEquirectangularMap(vec3 v)
{
    vec2 uv = vec2(atan2(v.z, v.x), asin(v.y));
    const vec2 invAtan = vec2(0.1591, 0.3183);
    uv *= invAtan;
    uv += 0.5;
    return uv;
}
#endif //!CUBEMAP_SKY

void main()
{
#ifdef CUBEMAP_SKY
    vec3 n = normalize(v_posWS.xyz);
    gl_FragColor = textureCube(s_skybox, n);
#else //!CUBEMAP_SKY
    vec2 uv = sampleEquirectangularMap(v_posWS.xyz);
    gl_FragColor = texture2D(s_skybox, uv);
#endif //CUBEMAP_SKY
    
}
