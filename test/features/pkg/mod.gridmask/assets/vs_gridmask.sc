$input  a_position
$output v_texcoord0

#include <bgfx_shader.sh>

uniform vec4 u_grid_bound;

void main()
{
	gl_Position = mul(u_modelViewProj, vec4(a_position, 1.0));

    vec2 uv = a_position.xz / u_grid_bound.zw;

    //from [-1, 1] -> [0, 1]
    uv = (uv+1.0)*0.5;
    uv.y = 1.0 - uv.y;  //texcoord.y from top to bottom
    v_texcoord0 = uv;
}