$input a_position, a_normal
#include <bgfx_shader.sh>

uniform vec4 u_outlinescale;

void main()
{
    vec2 vnormal = mul(u_modelView,vec4(a_normal, 0.0)).xy;
    vnormal = normalize(vnormal);
    vnormal = mul(u_proj,vec4(vnormal,0.0,0.0));
    vec4 temp = mul(u_modelViewProj, vec4(a_position, 1.0));
    gl_Position = temp+vec4(vnormal*((temp.w)*u_outlinescale.x),0.0,0.0);
    gl_Position.z = gl_Position.z + 0.01;
}