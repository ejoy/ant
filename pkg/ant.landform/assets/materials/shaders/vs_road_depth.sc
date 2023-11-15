$input a_position

#include <bgfx_shader.sh>
#include "road.sh"

struct VSInput{vec3 position;};
struct Varyings {vec3 posWS;};

void main()
{
    VSInput vsinput; vsinput.position = a_position;
    gl_Position = transform_road(vsinput, varyings);
}