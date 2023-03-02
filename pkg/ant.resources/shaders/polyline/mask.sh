#ifndef __POLYLINE_MASK_SH__
#define __POLYLINE_MASK_SH__

#ifdef ENABLE_POLYLINE_MASK
uniform vec4 u_grid_bound;

vec2 mask_uv(vec3 localpos)
{
	vec2 uv = localpos.xz / u_grid_bound.zw;

    //from [-1, 1] -> [0, 1]
    uv = (uv+1.0)*0.5;
    uv.y = 1.0 - uv.y;  //texcoord.y from top to bottom
    return uv;
}
#endif //ENABLE_POLYLINE_MASK

#endif //__POLYLINE_MASK_SH__