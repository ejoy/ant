$input v_texcoord0

/*
 * Copyright 2013-2014 Dario Manesku. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include "../common/common.sh"
SAMPLER2D(s_shadowMap0, 4);

uniform vec4 u_params2;
#define u_depthValuePow u_params2.x

void main()
{
	float depth = unpackRgbaToFloat(texture2D(s_shadowMap0, v_texcoord0) );
	float result = pow(depth, 10) ; //u_depthValuePow) );	
	gl_FragColor =  vec4(result, result, result, 1.0);
}
