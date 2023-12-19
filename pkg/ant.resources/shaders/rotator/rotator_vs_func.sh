#include "common/transform.sh"
#include "common/common.sh"
#include "default/utils.sh"

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

vec4 CUSTOM_VS_POSITION(VSInput vsinput, inout Varyings varyings, out mat4 wm)
{
#define DELTA_RADIAN (PI*0.1)
	wm = calc_rotator_transform(DELTA_RADIAN * u_current_time);
	vec4 posCS; varyings.posWS = transform_worldpos(wm, vsinput.position, posCS);
	return posCS;
#undef DELTA_RADIAN
}

void CUSTOM_VS(mat4 wm, VSInput vsinput, inout Varyings varyings)
{
#ifdef WITH_TEXCOORD0_ATTRIB
	varyings.texcoord0	= vsinput.texcoord0;
#endif //WITH_TEXCOORD0_ATTRIB

#ifdef WITH_COLOR0_ATTRIB
	varyings.color0 = vsinput.color0;
#endif //WITH_COLOR0_ATTRIB

#ifndef MATERIAL_UNLIT

#ifdef CALC_TBN
	varyings.normal	= mul((mat3)wm, vsinput.normal);
#else //!CALC_TBN
#	if TANGENT_PACK_FROM_QUAT
	unpack_tbn_from_quat(wm, vsinput, varyings);
#	else //!TANGENT_PACK_FROM_QUAT
	update_tbn(wm, vsinput, varyings);
#	endif//TANGENT_PACK_FROM_QUAT
#endif//CALC_TBN

#endif //!MATERIAL_UNLIT
}