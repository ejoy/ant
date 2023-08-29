#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
#include "default/inputs_structure.sh"

void CUSTOM_VS_FUNC(in VSInput vs_input, inout VSOutput vs_output)
{
    float road_texcoord_r = vs_input.idata1.x;
	float road_type       = vs_input.idata1.y;

	mat4 wm = get_world_matrix(vs_input);
	highp vec4 posWS = transform_pos(wm, vs_input.pos, vs_output.clip_pos);

	vs_output.uv0	    = get_rotated_texcoord(road_texcoord_r, vs_input.uv0).xy;
	vs_output.user0		= vec4(road_type, 0, 0, 0);
	vs_output.normal	= mul(wm, mediump vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	vs_output.tangent	= mul(wm, mediump vec4(1.0, 0.0, 0.0, 0.0)).xyz;
	vs_output.world_pos = posWS;
	vs_output.world_pos.w = mul(u_view, vs_output.world_pos).z;
}