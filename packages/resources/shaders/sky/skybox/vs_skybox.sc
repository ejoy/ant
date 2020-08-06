$input a_position
$output v_posWS

#include <bgfx_shader.sh>
uniform vec4 u_eyepos;

void main()
{
    v_posWS = a_position;
    gl_Position = mul(u_modelViewProj, vec4(v_posWS + u_eyepos.xyz, 1.0));
    gl_Position.z = gl_Position.w;
}
