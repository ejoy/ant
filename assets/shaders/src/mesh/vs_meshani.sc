$input a_position, a_texcoord0, a_normal, a_tangent, a_indices, a_weight
$output v_texcoord0, v_lightdir, v_viewdir, v_normal

#include <bgfx_shader.sh>
#include "common/uniforms.sh"
#include "common/animation.sh"

void main()
{
	mat4 worldMat = calc_bone_transform(a_indices, a_weight);
	vec4 pos = mul(worldMat, a_position);
	gl_Position = mul(u_viewProj, pos);

	v_texcoord0 = a_texcoord0;
	v_normal = a_normal;

	mat3 tbn = calc_tbn(a_normal, a_tangent, worldMat);
}