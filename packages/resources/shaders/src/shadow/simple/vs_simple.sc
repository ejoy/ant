$input a_position, a_normal
$output v_normal, v_viewdir, v_shadowcoord

#include "common.sh"
#include "common/uniforms.sh"
#include "common/shadow.sh"

void main()
{
    vec4 pos = vec4(a_position, 1.0);
	gl_Position = mul(u_modelViewProj, pos);

	vec4 wpos = mul(u_model[0], pos);
	
	v_viewdir = (u_eyepos - wpos).xyz;
	v_normal = a_normal;

	const float shadowMapOffset = 0.001;
	v_shadowcoord = calc_shadow_texcoord(directional_viewproj[0], a_position, a_normal, shadowMapOffset);
}
