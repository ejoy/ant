#ifndef __DRAW_INDIRECT_ROAD__
#define __DRAW_INDIRECT_ROAD__
#include "common/transform.sh"
vec4 transform_road(VSInput vsinput, inout Varyings varyings)
{
    #define ROAD_OFFSET_Y 0.1
    //TODO: the input local position can be vec2, but currently, our material system can not CUSTOM define VS_INPUT/VS_OUTPUT/FS_INPUT/FS_OUTPUT
	vec2 xzpos = vsinput.data0.xy;

	varyings.posWS = vec4(vsinput.position + vec3(xzpos[0], ROAD_OFFSET_Y, xzpos[1]), 1.0);
    return transform2clipspace(varyings.posWS);
}

#endif //__DRAW_INDIRECT_ROAD__