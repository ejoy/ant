#ifdef WITH_MASK
$input a_position, a_texcoord0, a_texcoord1
$output v_texcoord0, v_texcoord1
#else//!WITH_MASK
$input a_position, a_texcoord0
$output v_texcoord0
#endif//WITH_MASK

#include <bgfx_shader.sh>

void main()
{
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));

    v_texcoord0 = a_texcoord0;
#ifdef WITH_MASK
    v_texcoord1 = a_texcoord1;
#endif //WITH_MASK
}