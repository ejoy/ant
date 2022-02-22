$input v_texcoord0
#include <bgfx_shader.sh>
SAMPLER2D(s_tex, 0);
uniform vec4 u_param;
void main()
{
    int faceidx = int(u_param.x);
    vec4 colors[6] = {
        vec4(1.0, 0.0, 0.0, 1.0),
        vec4(0.0, 1.0, 0.0, 1.0),
        vec4(0.0, 0.0, 1.0, 1.0),
        vec4(1.0, 0.0, 1.0, 1.0),
        vec4(1.0, 1.0, 1.0, 1.0),
        vec4(0.0, 1.0, 1.0, 1.0),
    };
    gl_FragColor = texture2D(s_tex, v_texcoord0) + colors[faceidx];
}