#include "common/inputs.sh"

$input 	a_position a_texcoord0 INPUT_NORMAL  INPUT_TANGENT INPUT_LIGHTMAP_TEXCOORD INPUT_COLOR0 INPUT_INDICES INPUT_WEIGHT
$output v_texcoord0 OUTPUT_WORLDPOS OUTPUT_NORMAL OUTPUT_TANGENT OUTPUT_BITANGENT OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
#ifdef CS_SKINNING
    mat4 wm = u_model[0];
#else //!CS_SKINNING
    mat4 wm = get_world_matrix();
#endif //CS_SKINNING
	vec4 posWS = transformWS(wm, vec4(a_position, 1.0));
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
	const vec4 quat = a_tangent;
	vec3 normal, tangent;
	to_tangent_frame(quat, normal, tangent);
#	else //!PACK_TANGENT_TO_QUAT
	vec3 normal = a_normal;
	vec3 tangent = a_tangent.xyz;
#	endif//PACK_TANGENT_TO_QUAT
	v_normal	= normalize(mul(wm, vec4(normal, 0.0)).xyz);
	v_tangent	= normalize(mul(wm, vec4(tangent, 0.0)).xyz);
	v_bitangent	= cross(v_tangent, v_normal);	//left hand
#endif//CALC_TBN
#endif //!MATERIAL_UNLIT


}