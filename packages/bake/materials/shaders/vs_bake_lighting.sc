$input a_position, a_normal, a_tangent
$output v_normal
#include <bgfx_shader.sh>

void main()
{
	gl_Position   = mul(u_viewProj, v_posWS);

	v_normal	= normalize(mul(wm, vec4(a_normal, 0.0)).xyz);

    // bake lighting  will not sample normal map
	// v_tangent	= normalize(mul(wm, vec4(a_tangent, 0.0)).xyz);
	// v_bitangent	= cross(v_normal, v_tangent);	//left hand

	gl_Position = mul(u_worldViewProj, vec4(a_position, 1.0));
}