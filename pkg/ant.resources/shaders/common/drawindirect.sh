#ifndef __DRAWINDIRECT_SH__
#define __DRAWINDIRECT_SH__

//////////////////////////////////////////////////////////////////////////////////////////////
/// !! we NEED to REMOVE this file after the new feature of dynamic material support depth/picking and custom define drawtype
//////////////////////////////////////////////////////////////////////////////////////////////

#include "common/transform.sh"

#ifdef DRAW_INDIRECT

#ifdef DI_MOUNTAIN

#endif //DI_MOUNTAIN

vec4 transform_drawindirect_worldpos(VSInput vs_input, out vec4 posCS)
{
#ifdef DI_MOUNTAIN
    mat4 wm = mountain_worldmat(vs_input);
    return transform_worldpos(wm, vs_input.pos, posCS);
#endif //DI_MOUNTAIN

#ifdef DI_ROAD

#define ROAD_OFFSET_Y 0.1
    //TODO: the input local position can be vec2, but currently, our material system can not CUSTOM define VS_INPUT/VS_OUTPUT/FS_INPUT/FS_OUTPUT
    vec4 idata0 = vs_input.idata0;
	vec2 xzpos = idata0.xy;

	vec4 posWS = vec4(vs_input.pos + vec3(xzpos[0], ROAD_OFFSET_Y, xzpos[1]), 1.0);
    posCS = transform2clipspace(posWS);
    return posWS;
#endif //DI_ROAD
}
#endif //DRAW_INDIRECT


#endif //!__DRAW_INDIRECT_SH__