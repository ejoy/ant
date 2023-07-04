#include <bgfx_shader.sh>
#include <bgfx_compute.sh>
#include <shaderlib.sh>
#include "pbr/attribute_define.sh"
#include "pbr/attribute_uniforms.sh"
#include "common/default_inputs_structure.sh"

uniform vec4 u_colorTable;
void CUSTOM_FS_FUNC(in FSInput fs_input, inout FSOutput fs_output)
{
	float corner_alpha = texture2D(s_basecolor, fs_input.uv0);
	if(corner_alpha == 1){
		fs_output.color = vec4(u_colorTable.xyz, 0);
	}
	else{
		fs_output.color = u_colorTable;
	}
}