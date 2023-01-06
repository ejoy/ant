$input a_position, a_color0, a_texcoord0
$output v_PosP, v_UV1, v_VColor

#include <common.sh>

//uniform mat4 u_camera;
uniform mat4 u_cameraProj;
uniform vec4 u_UVInversed;
uniform vec4 u_vsFlipbookParameter;
void main()
{
//	vec3 wpos = mul(vec4(a_position, 1.0), u_model[0]).xyz;
//	vec4 proj_pos = mul(vec4(wpos, 1.0), u_viewProj);
	vec4 proj_pos = mul(u_cameraProj, vec4(a_position, 1.0));
	v_PosP = proj_pos;
	gl_Position = proj_pos;
	v_VColor = a_color0;
	vec2 uv1 = a_texcoord0;
    uv1.y = u_UVInversed.x + (u_UVInversed.y * uv1.y);
	v_UV1 = uv1;
}
