#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
#include "default/inputs_structure.sh"

mat4 calc_rotator_transform(float rad)
{
	float cosy = cos(rad);
	float siny = sin(rad);	
	mat4 rm = mat4(
		cosy,       0,      -siny,        0, 
		0,          1,          0,        0, 
		siny,       0,       cosy,        0, 
		0,          0,          0,        1
	);
	return mul(u_model[0], rm);
}

void CUSTOM_VS_FUNC(in VSInput vs_input, inout VSOutput vs_output)
{
#define delta_radian PI * 0.1
	mat4 wm = calc_rotator_transform(delta_radian * u_current_time);
	vec4 posWS = transform_worldpos(wm, vs_input.pos, vs_output.clip_pos);
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
	vs_output.normal	= mul(wm, vec4(vs_input.normal, 0.0)).xyz;
#else //!CALC_TBN
#	if TANGENT_PACK_FROM_QUAT
	const mediump vec4 quat = vs_input.tangent;
	mediump vec3 normal = quat_to_normal(quat);
	mediump vec3 tangent = quat_to_tangent(quat);
#	else //!TANGENT_PACK_FROM_QUAT
	mediump vec3 normal = vs_input.normal;
	mediump vec3 tangent = vs_input.tangent.xyz;
#	endif//TANGENT_PACK_FROM_QUAT
	vs_output.normal	= mul(wm, mediump vec4(normal, 0.0)).xyz;
	vs_output.tangent	= mul(wm, mediump vec4(tangent, 0.0)).xyz;
	vs_output.bitangent = cross(vs_output.tangent, vs_output.normal) * sign(vs_input.tangent.w);
#endif//CALC_TBN

#endif //!MATERIAL_UNLIT
}