#ifndef _PROCEDURAL_SKY_SH_
#define _PROCEDURAL_SKY_SH_

uniform vec4 	u_parameters; // x - sun size, y - sun bloom, z - intensity, w - time
#define u_sunSize		u_parameters.x
#define u_sunBloom		u_parameters.y
#define u_intensity	    u_parameters.z
#define u_dayTime		u_parameters.w
uniform vec4 	u_sunDirection;

uniform vec4 	u_sunLuminance;
uniform vec4    u_skyLuminanceXYZ;
uniform vec4    u_perezCoeff[5];

#endif //_PROCEDURAL_SKY_SH_