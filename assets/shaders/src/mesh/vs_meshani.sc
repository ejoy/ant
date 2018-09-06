$input a_position, a_texcoord0, a_normal, a_tangent, a_indices, a_weight
$output v_texcoord0, v_lightdir, v_viewdir, v_normal, v_tangent, v_bitangent

#include <bgfx_shader.sh>
#include "common/uniforms.sh"
#include "common/animation.sh"

void main()
{
	mat4 worldMat = calc_bone_transform(a_indices, a_weight);
	gl_Position = u_viewProj * wolrdMat * (pos * 0.25);


}