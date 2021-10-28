$input v_skyColor, v_screenPos, v_viewDir

/*
* Copyright 2017 Stanislav Pidhorskyi. All rights reserved.
* License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
*/


uniform vec4 	u_parameters; // x - sun size, y - sun bloom, z - exposition, w - time
#define u_sunSize		u_parameters.x
#define u_sunBloom		u_parameters.y
#define u_exposition	u_parameters.z
#define u_dayTime		u_parameters.w
uniform vec4 	u_sunDirection;
uniform vec4 	u_sunLuminance;

#include "common.sh"

// https://www.shadertoy.com/view/4ssXRX
// http://www.loopit.dk/banding_in_games.pdf
// http://www.dspguide.com/ch2/6.htm

//uniformly distributed, normalized rand, [0, 1)
float nrand(in vec2 n)
{
	return fract(sin(dot(n.xy, vec2(12.9898, 78.233)))* 43758.5453);
}

float n4rand_ss(in vec2 n)
{
	float nrnd0 = nrand( n + 0.07*fract(u_dayTime));
	float nrnd1 = nrand( n + 0.11*fract(u_dayTime+0.573953));
	return 0.23*sqrt(-log(nrnd0+0.00001))*cos(2.0*3.141592*nrnd1)+0.5;
}

void main()
{
	float size2 = u_sunSize * u_sunSize;

	vec3 lightDir = normalize(u_sunDirection.xyz);
	float distance = 2.0 * (1.0 - dot(normalize(v_viewDir), lightDir));
	float sun = exp(-distance/ u_sunBloom / size2) + step(distance, size2);
	float sun2 = min(sun * sun, 1.0);
	vec3 color = v_skyColor + sun2;
	float r = n4rand_ss(v_screenPos);
	color += vec3_splat(r)/40.0;
	gl_FragColor = vec4(color, 1.0);
}
