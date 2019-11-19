#ifndef __SHADER_POSTPROCESS_SH__
#define __SHADER_POSTPROCESS_SH__

#include <shaderlib.sh>

SAMPLER2D(s_mainview,           6);
SAMPLER2D(s_postprocess_input,  7);

uniform vec4 u_bright_threshold;
uniform vec4 u_tonemap_param;
#define u_exposure      u_tonemap_param.x
#define u_tonemap_gamma u_tonemap_param.y

vec3 Uncharted2Tonemap(vec3 color)
{
	float A = 0.15;
	float B = 0.50;
	float C = 0.10;
	float D = 0.20;
	float E = 0.02;
	float F = 0.30;
	float W = 11.2;
	return ((color*(A*color+C*B)+D*E)/(color*(A*color+B)+D*F))-E/F;
}

vec4 tonemap_ex(vec4 color, float exposure, float gamma)
{
	vec3 outcol = Uncharted2Tonemap(color.rgb * exposure);
	outcol = outcol * (1.0f / Uncharted2Tonemap(vec3_splat(11.2f)));	
	return vec4(pow(outcol, vec3_splat(1.0f / gamma)), color.a);
}

vec4 tonemap(vec4 color)
{
    return tonemap_ex(color, u_exposure, u_tonemap_gamma);
}

vec4 bloom_color(vec4 color)
{
    vec3 l = luma(toLinear(color.rgb));
    return step(u_bright_threshold.x, l.x) * color;
}

#endif //__SHADER_POSTPROCESS_SH__