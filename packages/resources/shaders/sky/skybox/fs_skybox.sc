$input v_posWS

#include <bgfx_shader.sh>
#include "common/utils.sh"

SAMPLERCUBE(s_skybox, 0);

uniform vec4 u_skybox_param;
#define u_skybox_intensity u_skybox_param.x

void main()
{
    vec3 n = normalize(v_posWS.xyz);
    vec4 color = textureCube(s_skybox, n);
    gl_FragColor = vec4(u_skybox_intensity * color.rgb, color.a);
    
}
