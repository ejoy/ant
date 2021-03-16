$input a_position, a_color0, a_texcoord0
$output v_color0, v_texcoord0, v_ppos

#include <common.sh>

//uniform mat4 mCamera;
//uniform mat4 mCameraProj;
uniform vec4 mUVInversed;
uniform vec4 mflipbookParameter;
void main()
{
//	vec3 wpos = mul(vec4(a_position, 1.0), u_model[0]).xyz;
//	vec4 proj_pos = mul(vec4(wpos, 1.0), u_viewProj);
	vec4 proj_pos = mul(u_viewProj, vec4(a_position, 1.0));
	v_ppos = proj_pos;
	gl_Position = proj_pos;
	v_color0 = a_color0;
	vec2 uv1 = a_texcoord0;
    uv1.y = mUVInversed.x + (mUVInversed.y * uv1.y);
	v_texcoord0 = uv1;
}
