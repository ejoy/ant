#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
#include "default/inputs_structure.sh"

#include "common/drawindirect.sh"

#ifndef WITH_CUSTOM_COLOR0_ATTRIB
#error "need custom v_color0"
#endif //!WITH_CUSTOM_COLOR0_ATTRIB

vec4 CUSTOM_TRANSFORM_VS_WORLDPOS(VSInput vs_input, inout VSOutput vs_output, out mat4 worldmat)
{
	worldmat = (mat4)0;
	return transform_drawindirect_worldpos(vs_input, vs_output.clip_pos);
}

void CUSTOM_VS_FUNC(in VSInput vs_input, inout VSOutput vs_output)
{
	mat4 wm_DONOT_USED;
	vec4 posWS = CUSTOM_TRANSFORM_VS_WORLDPOS(vs_input, vs_output, wm_DONOT_USED);

	uint color = floatBitsToUint(vs_input.idata0.z);
	vs_output.uv0	    = vs_input.uv0;
	vs_output.color		= vec4(uvec4(color, color>>8, color>>16, color>>24)&0xff) / 255.0;
	vs_output.normal	= vec3(0.0, 1.0, 0.0);
	vs_output.world_pos = posWS;
	vs_output.world_pos.w = mul(u_view, vs_output.world_pos).z;
}