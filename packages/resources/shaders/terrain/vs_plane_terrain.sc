#include "common/inputs.sh"

$input 	a_position a_texcoord0 a_texcoord1 a_texcoord2 a_texcoord3 a_texcoord4
$output v_texcoord0 v_texcoord1 v_texcoord2 v_texcoord3 v_texcoord4 v_normal v_tangent v_bitangent v_posWS v_idx1 v_idx2

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
	mat4 wm = get_world_matrix();
	vec4 posWS = transformWS(wm, vec4(a_position.xyz, 1.0));
	gl_Position = mul(u_viewProj, posWS);

	#ifdef HAS_PROCESSING
	
	v_texcoord0	= a_texcoord0;

	v_texcoord1 = a_texcoord1;

	v_normal	= normalize(mul(wm, vec4(0.0, 1.0, 0.0, 0.0)).xyz);

	v_tangent	= normalize(mul(wm, vec4(1.0, 0.0, 0.0, 0.0)).xyz);

	v_bitangent	= cross(v_normal, v_tangent);	//left hand

	v_posWS = posWS;
	v_posWS.w = mul(u_view, v_posWS).z;
	
	v_idx1 = vec2(a_texcoord2.x, a_texcoord2.y);
	v_idx2 = vec4(a_texcoord3.x, a_texcoord3.y, a_texcoord4.x, a_texcoord4.y);
	
	#endif
}