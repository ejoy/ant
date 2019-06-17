$input a_position, a_normal
$output v_normal, v_color0, v_viewdir
#include <bgfx_shader.sh>
#include "common/uniforms.sh"

// uniform vec4 u_eyepos;
uniform vec4 u_color;

void main()
{
    vec3 pos = a_position;
    gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
    vec4 wpos = mul(u_model[0], vec4(pos, 1.0));
    
    v_viewdir = (u_eyepos - wpos).xyz;
    v_color0 = u_color;
    v_normal = a_normal;
}