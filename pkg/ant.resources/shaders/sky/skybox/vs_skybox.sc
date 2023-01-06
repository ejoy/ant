$input a_position
$output v_posWS

#include <bgfx_shader.sh>
#include "common/camera.sh"

void main()
{
    v_posWS = a_position;
    gl_Position = mul(u_modelViewProj, vec4(v_posWS + u_eyepos.xyz, 1.0));
    gl_Position.z = 0.0;//gl_Position.w;
}
