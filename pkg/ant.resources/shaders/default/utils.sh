#ifndef __DEFAULT_UTILS_SH__
#define __DEFAULT_UTILS_SH__

#include "common/transform.sh"
vec4 custom_vs_position(VSInput vsinput, inout Varyings varyings, out mat4 worldmat)
{
    worldmat = u_model[0];
	vec4 posCS; varyings.posWS = transform_worldpos(wm, vsinput.position, posCS);
	return posCS;
}

void unpack_tbn_from_quat(mat4 mat, VSInput vsinput, inout Varyings varyings){
    unpack_tbn_from_quat((mat3)mat, vsinput.tangent, varyings.normal, varyings.tangent, varyings.bitangent);
}

void update_tbn(mat4 wm, VSInput vsinput, Varyings varyings)
{
    varyings.normal = vsinput.normal;
	varyings.tangent = vsinput.tangent.xyz;
	to_tbn((mat3)wm, sign(vsinput.tangent.w), varyings.normal, varyings.tangent, varyings.bitangent);
}

#endif //__DEFAULT_UTILS_SH__