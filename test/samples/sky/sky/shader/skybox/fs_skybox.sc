
$input v_color0,v_texcoord0

#include "../common/common.sh"
//#include <bgfx_shader.sh>
 
SAMPLERCUBE(s_texCube,0);
uniform vec4 u_lightScale;
void main()
{
    vec4 texColor = textureCube(s_texCube,v_texcoord0);
    gl_FragColor = texColor * (v_color0 * u_lightScale.x);
}