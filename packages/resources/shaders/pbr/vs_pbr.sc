$input  a_position, a_normal, a_texcoord0
$output v_texcoord0, v_normal, v_posWS

#include <bgfx_shader.sh>

#include "common/uniforms.sh"

// u_tiling can achieve through mesh converter when import asset
//uniform vec4 u_tiling;
void main()
{
    vec4 pos      = vec4(a_position, 1.0);
	gl_Position   = mul(u_modelViewProj, pos);

	vec4 worldpos = mul(u_model[0], pos);
	v_posWS       = vec4(worldpos.xyz, mul(u_view, worldpos).z);
	
	v_texcoord0   = a_texcoord0;//*u_tiling.xy;

	// normal need recalculate after tranform to world space
	v_normal		= normalize(mul(u_model[0], vec4(a_normal.xyz, 0.0))).xyz;
}