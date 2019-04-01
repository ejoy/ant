$input a_position
$output v_depth

#include <bgfx_shader.sh>

#include "common/uniforms.sh"

void main()
{
	vec4 pos = vec4(a_position, 1.0);
	vec4 wpos = mul(u_model[0], pos);
	gl_Position = mul(u_modelViewProj, pos);
	v_depth.x = length(u_lightPos - wpos);
	v_depth.yzw = vec3(0.0, 0.0, 0.0);
}