$input a_position
$output v_posWS

#include <bgfx_shader.sh>

void main()
{
    v_posWS = a_position;
    gl_Position = mul(u_modelViewProj, vec4(v_posWS, 1.0));
    gl_Position.z = gl_Position.w;
}
