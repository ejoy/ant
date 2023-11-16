$input a_position i_data0

#include <bgfx_shader.sh>
//define before "road.sh"
struct VSInput{vec3 position; vec4 data0; };
struct Varyings {vec4 posWS;};  //just to make compile happy

#include "road.sh"

void main()
{
    VSInput vsinput;
    vsinput.position = a_position;
    vsinput.data0 = i_data0;
    Varyings varyings;
    gl_Position = transform_road(vsinput, varyings);
}