$input a_position, a_normal
#include <bgfx_shader.sh>

uniform vec4 u_outlinescale;

float random (float2 uv)
{
    return frac(sin(dot(uv,float2(12.9898,78.233)))*43758.5453123);
}

void main()
{
    vec2 normal = mul(u_modelViewProj,vec4(a_normal, 0.0)).xy;
    normal = normalize(normal);
    vec4 temp = mul(u_modelViewProj, vec4(a_position, 1.0));
    gl_Position = temp+vec4(normal*((temp.w)*u_outlinescale.x),0.0,0.0);
    gl_Position.z = gl_Position.z + 0.01;

}