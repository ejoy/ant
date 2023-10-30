#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
#include "common/camera.sh"
#include "default/inputs_structure.sh"
#include "grid.sh"

void CUSTOM_VS_FUNC(in VSInput vs_input, inout VSOutput vs_output)
{
    vec3 worldPos = mul(u_model[0], vec4(vs_input.pos, 1.0)).xyz;
    vs_output.clip_pos = mul(u_viewProj, vec4(worldPos, 1.0));
    
    vec3 gridScale = vec3(u_grid_width, 1.0, u_grid_height);
    float3 cameraCenteringOffset = floor(u_eyepos.xyz * gridScale);

	vs_output.uv0 = (worldPos * gridScale - cameraCenteringOffset).xz;
}