$input a_position, a_normal, a_texcoord0
$output v_texcoord0, v_viewdir,v_normal

#include <bgfx_shader.sh>
#include "common/camera.sh"

void main()
{
    vec4 pos = vec4(a_position, 1);
	gl_Position = mul(u_modelViewProj, pos);
	vec4 worldpos = mul(u_model[0], pos);

	v_viewdir 	= normalize(u_eyepos.xyz - worldpos.xyz);
	v_normal    = a_normal;
	v_texcoord0 = a_texcoord0;
}