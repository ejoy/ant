$input a_position, a_normal
$output v_normal, v_viewdir, v_shadowcoord

#include <bgfx_shader.sh>
#include "common/shadow.sh"
#include "common/camera.sh"

void main()
{
    vec4 pos = vec4(a_position, 1.0);
	gl_Position = mul(u_modelViewProj, pos);

	vec4 wpos = mul(u_model[0], pos);
	
	v_viewdir = (u_eyepos - wpos).xyz;
	v_normal = mul(u_model[0], vec4(a_normal, 1.0));

	const float shadowMapOffset = 0.001;
	v_shadowcoord = calc_shadow_texcoord(directional_viewproj[0], wpos.xyz, v_normal, shadowMapOffset);
	v_shadowcoord.xy = v_shadowcoord.xy * 0.5 + 0.5;
}
