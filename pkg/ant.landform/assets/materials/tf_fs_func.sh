#include <bgfx_shader.sh>
#include <bgfx_compute.sh>
#include <shaderlib.sh>
#include "common/uvmotion.sh"
#include "default/inputs_structure.sh"

void CUSTOM_FS_FUNC(in FSInput fsinput, inout FSOutput fsoutput)
{
	float corner_alpha = texture2D(s_basecolor, fsinput.uv0);
	fsoutput.color = vec4(u_basecolor_factor.xyz, corner_alpha * u_basecolor_factor.a);
}