#include <bgfx_shader.sh>
#include <shaderlib.sh>
#include "default/inputs_structure.sh"
#include "grid.sh"
#include "common/uvmotion.sh"

void CUSTOM_FS_FUNC(in FSInput fsinput, inout FSOutput fsoutput)
{
    float grid = pristineGrid(fsinput.uv0, u_line_scale);
	fsoutput.color = vec4(u_basecolor_factor.xyz, grid);
}