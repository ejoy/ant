#include "common/transform.sh"
#include "common/common.sh"
#include "default/utils.sh"

vec4 CUSTOM_VS_POSITION(VSInput vsinput, inout Varyings varyings, out mat4 worldmat)
{
	return custom_vs_position(vsinput, varyings, worldmat);
}

void CUSTOM_VS(mat4 worldmat, VSInput vsinput, inout Varyings varyings)
{
	varyings.texcoord0	= vsinput.texcoord0;
	varyings.posWS.w 	= mul(u_view, varyings.posWS).z;
}