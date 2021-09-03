$input a_position, a_texcoord0, a_color0
$output v_texcoord0, v_color0
#include <bgfx_shader.sh>

void main()
{
    vec4 wpos = mul(u_model[0], vec4(a_position, 1.0));
    vec4 vpos = mul(u_view, wpos);
    gl_Position = mul(u_proj, vpos);
    v_texcoord0 = a_texcoord0;
    v_color0 = a_color0;
}