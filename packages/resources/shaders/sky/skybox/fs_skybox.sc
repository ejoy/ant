$input v_posWS

#include <bgfx_shader.sh>
SAMPLERCUBE(s_skybox, 0);

void main()
{
    vec3 n = normalize(v_posWS.xyz);
    gl_FragColor = textureCube(s_skybox, n);
}
