#ifndef _IBL_SOURCE_SH_
#define _IBL_SOURCE_SH_

#include "common/common.sh"

#ifdef CUBEMAP_SOURCE
SAMPLERCUBE(s_source, 0);
#define SOURCE_TYPE     BgfxSamplerCube
#else //!CUBEMAP_SOURCE
SAMPLER2D(s_source, 0);
#define SOURCE_TYPE BgfxSampler2D
#endif //CUBEMAP_SOURCE

vec4 sample_source(SOURCE_TYPE s, vec3 dir, int lod)
{
#ifdef CUBEMAP_SOURCE
    return textureCubeLod(s, dir, lod);
#else //!CUBEMAP_SOURCE
    vec2 uv = dir2spherecoord(normalize(dir));
    return texture2DLod(s, uv, lod);
#endif //CUBEMAP_SOURCE
}

#endif //_IBL_SOURCE_SH_