#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
#include "common/default_inputs_structure.sh"

void CUSTOM_VS_FUNC(in VSInput vs_input, inout VSOutput vs_output)
{
#ifdef DRAW_INDIRECT
	mediump mat4 wm = get_indirect_world_matrix(vs_input.idata0, vs_input.idata1, vs_input.idata2, u_draw_indirect_type);
#else
	mediump mat4 wm = get_world_matrix_default(vs_input);
#endif //DRAW_INDIRECT

	highp vec4 posWS = transformWS(wm, mediump vec4(vs_input.pos, 1.0));
	vec4 clipPos = mul(u_viewProj, posWS);
	clipPos += u_jitter * clipPos.w; // Apply Jittering
	vs_output.clip_pos = clipPos;

	vs_output.uv0	= vs_input.uv0;
#ifdef USING_LIGHTMAP
	vs_output.uv1 = vs_input.uv1;
#endif //USING_LIGHTMAP

#ifdef WITH_COLOR_ATTRIB
	vs_output.color = vs_input.color;
#endif //WITH_COLOR_ATTRIB

#ifndef MATERIAL_UNLIT
	vs_output.world_pos = posWS;
	vs_output.world_pos.w = mul(u_view, vs_output.world_pos).z;

#ifdef CALC_TBN
	vs_output.normal	= normalize(mul(wm, vec4(vs_input.normal, 0.0)).xyz);
#else //!CALC_TBN
#	if PACK_TANGENT_TO_QUAT
	const mediump vec4 quat = vs_input.tangent;
	mediump vec3 normal = quat_to_normal(quat);
	mediump vec3 tangent = quat_to_tangent(quat);
#	else //!PACK_TANGENT_TO_QUAT
	mediump vec3 normal = vs_input.normal;
	mediump vec3 tangent = vs_input.tangent.xyz;
#	endif//PACK_TANGENT_TO_QUAT
	vs_output.normal	= mul(wm, mediump vec4(normal, 0.0)).xyz;
	vs_output.tangent	= mul(wm, mediump vec4(tangent, 0.0)).xyz * sign(vs_input.tangent.w);
#endif//CALC_TBN

#endif //!MATERIAL_UNLIT
}