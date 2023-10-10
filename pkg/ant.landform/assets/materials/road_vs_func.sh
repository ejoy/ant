#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
#include "default/inputs_structure.sh"

#ifndef WITH_CUSTOM_COLOR0_ATTRIB
#error "need custom v_color0"
#endif //!WITH_CUSTOM_COLOR0_ATTRIB

#define ROAD_OFFSET_Y 0.1

void CUSTOM_VS_FUNC(in VSInput vs_input, inout VSOutput vs_output)
{
    float road_texcoord_r = vs_input.idata0.z;
	float road_state      = vs_input.idata0.w;

	vec4 idata0 = vs_input.idata0;
	vec2 xzpos = idata0.xy;

	highp vec4 posWS = vec4(vs_input.pos + vec3(xzpos[0], ROAD_OFFSET_Y, xzpos[1]), 1.0);
	uint color = floatBitsToUint(idata0.z);

	vs_output.clip_pos = transform2clipspace(posWS);

	vs_output.uv0	    = get_rotated_texcoord(road_texcoord_r, vs_input.uv0).xy;
	vs_output.color		= vec4(uvec4(color, color>>8, color>>16, color>>24)&0xff) / 255.0;
	vs_output.normal	= vec3(0.0, 1.0, 0.0);
	vs_output.tangent	= vec3(1.0, 0.0, 0.0);
	vs_output.bitangent = vec3(0.0, 0.0,-1.0);
	vs_output.world_pos = posWS;
	vs_output.world_pos.w = mul(u_view, vs_output.world_pos).z;
}