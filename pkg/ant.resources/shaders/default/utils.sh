#ifndef __DEFAULT_UTILS_SH__
#define __DEFAULT_UTILS_SH__

#include "common/transform.sh"

#ifdef WITH_POSITION_ATTRIB
vec4 custom_vs_position(VSInput vsinput, inout Varyings varyings, mat4 worldmat)
{
	vec4 posCS;
	varyings.posWS = transform_worldpos(worldmat, vsinput.position, posCS);
	return posCS;
}
#endif //WITH_POSITION_ATTRIB

#ifdef WITH_TANGENT_ATTRIB

#if TANGENT_PACK_FROM_QUAT
void unpack_tbn_from_quat(mat4 mat, VSInput vsinput, inout Varyings varyings){
    unpack_tbn_from_quat((mat3)mat, vsinput.tangent, varyings.normal, varyings.tangent, varyings.bitangent);
}
#else //!TANGENT_PACK_FROM_QUAT
void update_tbn(mat4 wm, VSInput vsinput, Varyings varyings)
{
    varyings.normal = vsinput.normal;
	varyings.tangent = vsinput.tangent.xyz;
	to_tbn((mat3)wm, sign(vsinput.tangent.w), varyings.normal, varyings.tangent, varyings.bitangent);
}
#endif //TANGENT_PACK_FROM_QUAT

#endif //WITH_TANGENT_ATTRIB

#endif //__DEFAULT_UTILS_SH__