#include <bgfx_shader.sh>
$input a_position
$ouput v_viewray

void main() {
    vec4 pos = vec4(a_position, 1.0);
    v_viewray = mul(u_invViewProj, pos).xyz;
    gl_Position = pos;
}