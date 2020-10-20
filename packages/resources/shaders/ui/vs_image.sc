$input a_position, a_color0, a_texcoord0
$output v_texcoord0, v_color0
#include <bgfx_shader.sh>
void main()
{
    vec4 p      = mul(u_model[0], vec4(a_position, 0.0, 1.0));
    vec2 pos    = p.xy * u_viewTexel.xy;
    pos.y       = 1 - pos.y;
	pos         = pos * 2.0 - 1.0;
	gl_Position = vec4(pos, 0.0, 1.0);
    v_texcoord0 = a_texcoord0;
    v_color0    = a_color0;
}