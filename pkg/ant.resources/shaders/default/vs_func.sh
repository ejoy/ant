#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
#include "default/inputs_structure.sh"
#include "default/output_vs_attrib.sh"

//TODO: we need CUSTOM_TRANSFORM_VS_WORLDPOS function for custom define how to transform the world pos from input attribute
vec4 CUSTOM_TRANSFORM_VS_WORLDPOS(VSInput vs_input, inout VSOutput vs_output, out mat4 worldmat)
{
	worldmat = get_world_matrix(vs_input);
	return transform_worldpos(worldmat, vs_input.pos, vs_output.clip_pos);
}

void CUSTOM_VS_FUNC(in VSInput vs_input, inout VSOutput vs_output)
{
	mat4 wm;
	vec4 posWS = CUSTOM_TRANSFORM_VS_WORLDPOS(vs_input, vs_output, wm);
	output_vs_attrib(posWS, wm, vs_input, vs_output);
}