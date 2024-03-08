$input a_position a_color0 a_texcoord0
$output v_color0 v_texcoord0

#include <bgfx_shader.sh>

uniform vec4 u_param;
#define u_layer u_param.x

float n2s(float v)
{
    return v * 2.0 - 1.0;
}

void main()
{
    //a_position are in rect, define origin in left top of screen
    //we assume u_model define a transfrom in 2d screen, the 3 column will not use
    vec4 pos = mul(u_model[0], vec4(a_position, 0.0, 1.0));

    vec2 pos2d = pos.xy * u_viewTexel.xy;
    pos2d.x = n2s(pos2d.x);
    pos2d.y = n2s(1.0-pos2d.y);

    gl_Position = vec4(pos2d, u_layer, 1.0);
    v_color0 = a_color0;
    v_texcoord0 = a_texcoord0;
}