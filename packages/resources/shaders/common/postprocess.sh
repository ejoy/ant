#ifndef __SHADER_POSTPROCESS_SH__
#define __SHADER_POSTPROCESS_SH__

#include <shaderlib.sh>

SAMPLER2D(s_mainview,           6);
SAMPLER2D(s_postprocess_input,  7);

uniform vec4 u_bright_threshold;

vec4 bloom_color(vec4 color)
{
    vec3 l = luma(toLinear(color.rgb));
    return step(u_bright_threshold.x, l.x) * color;
}

#endif //__SHADER_POSTPROCESS_SH__