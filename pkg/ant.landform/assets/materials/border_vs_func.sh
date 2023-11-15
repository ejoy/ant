#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
#include "default/utils.sh"

vec4 CUSTOM_VS_POSITION(VSInput vsinput, inout Varyings varyings, out mat4 worldmat){
	return custom_vs_position(vsinput, varyings, worldmat);
}

void CUSTOM_VS(mat4 wm, VSInput vsinput, inout Varyings varyings)
{
	varyings.texcoord0	= vsinput.texcoord0;
	mat3 wm3 = (mat3)wm;
	varyings.normal		= mul(wm3, vec3(0.0, 1.0, 0.0));
	varyings.tangent	= mul(wm3, vec3(1.0, 0.0, 0.0));
	varyings.bitangent	= mul(wm3, vec3(0.0, 0.0,-1.0));
	varyings.posWS.w 	= mul(u_view, varyings.posWS).z;
}