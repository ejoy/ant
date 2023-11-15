#include "grid.sh"
#include "common/uvmotion.sh"

void CUSTOM_FS(Varyings varyings, inout FSOutput fsoutput)
{
    float grid = pristineGrid(varyings.texcoord0, u_line_scale);
	fsoutput.color = vec4(u_basecolor_factor.xyz, grid);
}