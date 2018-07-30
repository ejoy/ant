$input a_position, a_texcoord0 ,a_normal,a_texcoord1
$output v_position, v_texcoord0,v_normal,v_texcoord1

/*
 * Copyright 2015 Andrew Mac. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include "common.sh"

void main()
{
	v_position = a_position.xyz;
	v_texcoord0 = a_texcoord0;
	v_texcoord1 = a_texcoord1;
	v_normal = a_normal.xyz;   					// modelviewproj *a_normal 

	gl_Position = mul(u_modelViewProj, vec4(v_position.xyz, 1.0));
}
