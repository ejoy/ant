$input a_position, a_color0  
$output v_color0, v_texcoord0
#include <bgfx_shader.sh>

void main()
{
    vec3 pos = a_position;
    gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
    gl_Position = gl_Position.xyww;
    v_texcoord0 = vec4(pos,1.0f);
    v_color0 = a_color0;
 }