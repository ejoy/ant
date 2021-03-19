$input v_texcoord0
#include <bgfx_shaders.sh>

SAMPLER2D(u_tex, 0);

uniform vec4 u_uvmotion_speed;

void main()
{
    vec2 uv = v_texcoord0 * u_uvmotion_speed.xy;

}