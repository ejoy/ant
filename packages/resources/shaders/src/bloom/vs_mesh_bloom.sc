$input  a_position, a_texcoord0 
$output v_texcoord0 

#include <bgfx_shader.sh>  
#include "common/uniforms.sh"
     
void main() 
{
    vec3 pos    = a_position;
    v_texcoord0 = a_texcoord0;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
}