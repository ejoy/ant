#include "common/transform.sh"
#include "common/common.sh"

vec4 CUSTOM_VS_POSITION(VSInput vsinput, inout Varyings varyings, out mat worldmat)
{
	worldmat = u_model[0];
	vec4 posCS; varyings.posWS = transform_worldpos(wm, vsinput.position, posCS);
	return posCS;
}

void CUSTOM_VS(VSInput vsinput, inout Varyings varyings)
{
	varyings.texcoord0	= vsinput.texcoord0;
	varyings.posWS.w 	= mul(u_view, varyings.posWS).z;
}