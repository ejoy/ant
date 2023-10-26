#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
#include "default/inputs_structure.sh"

void CUSTOM_VS_FUNC(in VSInput vs_input, inout VSOutput vs_output)
{
	mat4 wm = get_world_matrix(vs_input);
	highp vec4 posWS = transform_worldpos(wm, vs_input.pos, vs_output.clip_pos);
	vs_output.user0 = vs_input.user0;
	mat3 wm3 = (mat3)wm;
	vs_output.normal	= mul(wm3, mediump vec3(0.0, 1.0, 0.0));
	vs_output.tangent	= mul(wm3, mediump vec3(1.0, 0.0, 0.0));
	vs_output.bitangent = mul(wm3, mediump vec3(0.0, 0.0,-1.0));
	vs_output.world_pos = posWS;
	vs_output.world_pos.w = mul(u_view, vs_output.world_pos).z;
}