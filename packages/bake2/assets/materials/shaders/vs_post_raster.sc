#include <bgfx_shader.sh>

static vec2 ps[4] = {
   vec2(-1.0, 1.0), vec2(3.0, 1.0), vec2(-1.0, -3.0),
};

void main()
{
    gl_Position = vec4(ps[gl_VertexID], 1.0, 1.0);
}
