$input a_position

/*
 * Copyright 2011-2018 Branimir Karadzic. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include <bgfx_shader.sh>
#include "common/curve_world.sh"

#if CURVE_WORLD
uniform mat4 u_viewcamera_viewmat;
uniform mat4 u_viewcamera_inv_viewmat;
#endif //CURVE_WORLD

void main()
{
	vec3 posWS = a_position;
#if CURVE_WORLD
	posWS = curve_world_offset(posWS, u_viewcamera_viewmat, u_viewcamera_inv_viewmat);
	gl_Position   = mul(u_viewProj, vec4(posWS, 1.0));
#else
	gl_Position = mul(u_modelViewProj, vec4(posWS, 1.0));
#endif //CURVE_WORLD
	
}
