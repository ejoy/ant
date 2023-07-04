#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
#include "common/default_inputs_structure.sh"

void CUSTOM_VS_FUNC(in VSInput vs_input, inout VSOutput vs_output)
{
	mat4 wm = u_model[0];
	highp vec4 posWS = transformWS(wm, mediump vec4(vs_input.pos, 1.0));
	vs_output.uv0 = vs_input.uv0;
	vs_output.clip_pos   = mul(u_viewProj, posWS);	
}