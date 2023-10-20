#ifndef __DEFAULT_OUTPUT_VS_ATTRIB_SH__
#define __DEFAULT_OUTPUT_VS_ATTRIB_SH__

void output_vs_attrib(in vec4 posWS, in mat4 worldmat, in VSInput vs_input, inout VSOutput vs_output)
{
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

    mat3 wm3 = (mat3)worldmat;
#ifdef CALC_TBN
	vs_output.normal	= mul(wm3, vs_input.normal);
#else //!CALC_TBN
#	if PACK_TANGENT_TO_QUAT
	const mediump vec4 quat = vs_input.tangent;
	mediump vec3 normal = quat_to_normal(quat);
	mediump vec3 tangent = quat_to_tangent(quat);
#	else //!PACK_TANGENT_TO_QUAT
	mediump vec3 normal = vs_input.normal;
	mediump vec3 tangent = vs_input.tangent.xyz;
#	endif//PACK_TANGENT_TO_QUAT
	vs_output.normal	= mul(wm3, normal);
	vs_output.tangent	= mul(wm3, tangent);
	vs_output.bitangent = cross(vs_output.normal, vs_output.tangent) * sign(vs_input.tangent.w);
#endif//CALC_TBN

#endif //!MATERIAL_UNLIT
}

#endif //!__DEFAULT_OUTPUT_VS_ATTRIB_SH__