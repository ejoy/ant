#include "common/inputs.sh"

$input 	a_position a_texcoord0 INPUT_NORMAL INPUT_TANGENT INPUT_LIGHTMAP_TEXCOORD INPUT_COLOR0 INPUT_INDICES INPUT_WEIGHT INPUT_INSTANCE1 INPUT_INSTANCE2 INPUT_INSTANCE3
$output v_texcoord0 OUTPUT_WORLDPOS OUTPUT_NORMAL OUTPUT_TANGENT OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0 OUTPUT_EMISSIVE

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
#ifdef DRAW_INDIRECT
	mediump mat4 wm = get_indirect_wolrd_matrix(i_data0, i_data1, i_data2, u_draw_indirect_type);
#else
	mediump mat4 wm = get_world_matrix();
#endif //DRAW_INDIRECT

	highp vec4 posWS = transformWS(wm, mediump vec4(a_position, 1.0));
	gl_Position = mul(u_viewProj, posWS);

	v_texcoord0	= a_texcoord0;
#ifdef USING_LIGHTMAP
	v_texcoord1 = a_texcoord1;
#endif //USING_LIGHTMAP

#ifdef WITH_COLOR_ATTRIB
	v_color0 = a_color0;
#endif //WITH_COLOR_ATTRIB

#ifndef MATERIAL_UNLIT
	v_posWS = posWS;
	v_posWS.w = mul(u_view, v_posWS).z;

#ifdef CALC_TBN
	v_normal	= normalize(mul(wm, vec4(a_normal, 0.0)).xyz);
#else //!CALC_TBN
#	if PACK_TANGENT_TO_QUAT
	const mediump vec4 quat = a_tangent;
	mediump vec3 normal = quat_to_normal(quat);
	mediump vec3 tangent = quat_to_tangent(quat);
#	else //!PACK_TANGENT_TO_QUAT
	mediump vec3 normal = a_normal;
	mediump vec3 tangent = a_tangent.xyz;
#	endif//PACK_TANGENT_TO_QUAT
	v_normal	= mul(wm, mediump vec4(normal, 0.0)).xyz;
	v_tangent	= mul(wm, mediump vec4(tangent, 0.0)).xyz * sign(a_tangent.w);
#endif//CALC_TBN

#endif //!MATERIAL_UNLIT
}