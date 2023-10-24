#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/drawindirect.sh"

#include "default/inputs_structure.sh"
#include "default/output_vs_attrib.sh"
#ifndef DRAW_INDIRECT
#error "mountain need DRAW_INDIRECT"
#endif //!DRAW_INDIRECT

vec4 CUSTOM_TRANSFORM_VS_WORLDPOS(VSInput vs_input, inout VSOutput vs_output, out mat4 worldmat)
{
    worldmat = mountain_worldmat(vs_input);
    return transform_worldpos(worldmat, vs_input.pos, vs_output.clip_pos);
}

void CUSTOM_VS_FUNC(in VSInput vs_input, inout VSOutput vs_output)
{
    mat4 wm;
    vec4 posWS = CUSTOM_TRANSFORM_VS_WORLDPOS(vs_input, vs_output, wm);
	output_vs_attrib(posWS, wm, vs_input, vs_output);
}