#include "common/inputs.sh"

$input a_position INPUT_INDICES INPUT_WEIGHT INPUT_INSTANCE1 INPUT_INSTANCE2 INPUT_INSTANCE3

/*
 * Copyright 2011-2018 Branimir Karadzic. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include <bgfx_shader.sh>
#include "common/curve_world.sh"
#include "common/transform.sh"

#if CURVE_WORLD
uniform mat4 u_viewcamera_viewmat;
uniform mat4 u_viewcamera_inv_viewmat;
#endif //CURVE_WORLD

void main()
{
#ifdef CS_SKINNING
	mat4 wm = u_model[0];
#else //!CS_SKINNING
	mat4 wm = get_world_matrix();
#endif //CS_SKINNING

#if (defined HEAP_MESH) || (defined ROAD)
	wm[0][3] = wm[0][3] + i_data0.x;
	wm[1][3] = wm[1][3] + i_data0.y;
	wm[2][3] = wm[2][3] + i_data0.z;
#endif 

#ifdef STONE_MOUNTAIN
	float scale = i_data0.x;
	float scale_y = scale;
	float tx = i_data0.y;
	float tz = i_data0.z;
	float cosy = i_data0.w;
	float scosy = cosy * scale;
	float ssiny = sqrt(1 - cosy*cosy) * scale;
 	if(scale_y > 1){
		scale_y = scale_y * 0.5;
	}
 	wm = mat4(
		scosy,            0,     -ssiny,       tx, 
		0    ,      scale_y,          0,        0, 
	    ssiny,            0,      scosy,       tz, 
		0    ,            0,          0,        1
	);	 		 
#endif //STONE_MOUNTAIN

    highp vec3 posWS = transformWS(wm, mediump vec4(a_position, 1.0)).xyz;

#if CURVE_WORLD
	posWS = curve_world_offset(posWS, u_viewcamera_viewmat, u_viewcamera_inv_viewmat);
#endif //CURVE_WORLD

	gl_Position   = mul(u_viewProj, vec4(posWS, 1.0));
}
