$input a_position, a_normal
#include <bgfx_shader.sh>

uniform vec4 u_outlinescale;
#define u_outline_width u_outlinescale.x

void main()
{
    vec2 screen_normal = mul(u_modelViewProj, vec4(a_normal, 0.0)).xy;
    screen_normal = normalize(screen_normal);

    //make x direction offset same as y direction
    float w = u_viewRect.z;
    float h = u_viewRect.w;
    screen_normal.x *= h / w;

    // offset posision in clip space
    float zoffset = 0.01;
    vec4 clipPos = mul(u_modelViewProj, vec4(a_position, 1.0));
    gl_Position = clipPos;
    gl_Position.xyz += vec3(screen_normal * u_outline_width, zoffset) * clipPos.w;
}