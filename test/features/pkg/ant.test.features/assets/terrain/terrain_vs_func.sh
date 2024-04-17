#include "common/transform.sh"
#include "common/common.sh"
#include "default/utils.sh"

void CUSTOM_VS(mat4 worldmat, VSInput vsinput, inout Varyings varyings)
{
	varyings.texcoord0	= vsinput.texcoord0;
	varyings.normal		= vec3(0, 1, 0);
	varyings.tangent	= vec3(1, 0, 0);
	varyings.bitangent 	= vec3(0, 0, -1);
}