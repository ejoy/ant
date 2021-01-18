$input a_position, a_normal
#include <bgfx_shader.sh>

uniform vec4 u_outlinescale;
#define u_outline_width u_outlinescale.x

void main()
{
    mat4 it_view = transpose(u_invView);
    vec4 view_normal = mul(it_view, vec4(a_normal, 0.0));

    vec2 screen_normal = mul(u_proj, view_normal).xy;
    screen_normal = normalize(screen_normal);

    // offset posision in clip space
    vec4 clipPos = mul(u_modelViewProj, vec4(a_position, 1.0));
    gl_Position = clipPos;
    gl_Position.xy += screen_normal * u_outline_width * clipPos.w;
}