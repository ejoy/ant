$input a_position, a_texcoord0, a_normal, a_tangent, a_indices, a_weight
$output v_texcoord0, v_lightdir, v_viewdir, v_normal

#include <bgfx_shader.sh>
#include "common/uniforms.sh"
#include "common/animation.sh"
#include "common/transform.sh"

void main()
{
	mat4 worldMat = calc_bone_transform(a_indices, a_weight);
	vec4 pos = mul(worldMat, vec4(a_position, 1));
	gl_Position = mul(u_viewProj, pos);

	mat3 tbn = calc_tbn_lh(a_normal, a_tangent, worldMat);
	v_lightdir 	= mul(directional_lightdir.xyz , tbn);
	v_viewdir 	= mul(normalize(u_eyepos.xyz - pos.xyz), tbn);	

	v_texcoord0 = a_texcoord0;
	v_normal = a_normal;
}