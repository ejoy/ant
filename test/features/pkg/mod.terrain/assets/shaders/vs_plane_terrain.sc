#include "common/inputs.sh"

$input 	a_position a_texcoord0 a_texcoord1 a_texcoord2 a_texcoord3 a_texcoord4 a_texcoord5 a_texcoord6 a_texcoord7
$output v_texcoord0 v_texcoord1 v_texcoord2 v_normal v_tangent v_bitangent v_posWS v_idx1 v_idx2 v_texcoord3

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
    mat4 wm = u_model[0];
	highp vec4 posWS = transformWS(wm, mediump vec4(a_position, 1.0));

	gl_Position = mul(u_viewProj, posWS);

	v_texcoord0	= a_texcoord0;
	v_texcoord1 = a_texcoord1;
	v_texcoord2 = a_texcoord2;
	v_texcoord3 = a_texcoord7;

	v_idx1		= vec4(a_texcoord3.xy, a_texcoord6.xy);
	v_idx2		= vec4(a_texcoord4.xy, a_texcoord5.xy);

	v_normal	= mul(wm, mediump vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	v_tangent	= mul(wm, mediump vec4(1.0, 0.0, 0.0, 0.0)).xyz;

	v_posWS = posWS;
	v_posWS.w = mul(u_view, v_posWS).z;
}