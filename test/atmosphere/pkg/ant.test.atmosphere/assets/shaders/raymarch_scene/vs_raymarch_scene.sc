$input a_position
$output v_viewray

#include <bgfx_shader.sh>

uniform mat4 model_from_view;
uniform mat4 view_from_clip;

void main() {
    v_viewray = mul(u_invViewProj, a_position).xyz;
    //view_ray = (model_from_view * vec4((view_from_clip * vertex).xyz, 0.0)).xyz;
    gl_Position = a_position;
}