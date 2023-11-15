#include "common/transform.sh"
#include "common/common.sh"
#include "common/camera.sh"
#include "default/utils.sh"

#include "grid.sh"

vec4 CUSTOM_VS_POSITION(VSInput vsinput, inout Varyings varyings, out mat4 worldmat){
    return custom_vs_position(vsinput, varyings, worldmat);
}

void CUSTOM_VS(mat4 worldmat, in VSInput vsinput, inout Varyings varyings)
{
    vec3 gridScale = vec3(u_grid_width, 1.0, u_grid_height);
    vec3 cameraCenteringOffset = floor(u_eyepos.xyz * gridScale);

	varyings.texcoord0 = (varyings.posWS.xyz * gridScale - cameraCenteringOffset).xz;
}