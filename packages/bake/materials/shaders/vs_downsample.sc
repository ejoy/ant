#include <bgfx_shader.sh>

static vec2 ps[4] = {
   vec2(1, -1), vec2(1, 1), vec2(-1, -1), vec2(-1, 1)
};

void main()
{
   gl_Position = vec4(ps[gl_VertexID], 0, 1);
}