$input a_position

#include <bgfx_shader.sh>

#include "common/uniforms.sh"

void main()
{
	gl_Position = mul(u_modelViewProj, vec4(a_position, 1.0));	
}