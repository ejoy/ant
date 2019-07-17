$input a_position, a_normal
#include <bgfx_shader.sh>

uniform vec4 u_outlinescale;

void main()
{
    vec3 pos = a_position + u_outlinescale.x * a_normal;
    gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
}