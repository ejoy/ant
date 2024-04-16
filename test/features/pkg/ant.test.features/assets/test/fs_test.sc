$input v_bitangent v_normal v_posWS v_tangent v_texcoord0
#include <bgfx_shader.sh>
uniform vec4 u_color;
uniform vec4 u_lightdir;
void main()
{
    vec4 indirectcolor = vec4(0.1, 0.1, 0.1, 0.0);
    float NdotL = max(0.0, dot(normalize(u_lightdir.xyz), normalize(v_normal)));
    gl_FragColor = u_color * NdotL + indirectcolor;
}