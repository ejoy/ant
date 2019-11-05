$input v_texcoord0

#include <bgfx_shader.sh>
#include "common/postprocess.sh"

uniform vec4 u_bright_threshold;

// Luminance (standard for certain colour spaces): (0.2126*R + 0.7152*G + 0.0722*B) [1]
// Luminance (perceived option 1): (0.299*R + 0.587*G + 0.114*B) [2]
// Luminance (perceived option 2, slower to calculate): sqrt( 0.241*R^2 + 0.691*G^2 + 0.068*B^2 ) → sqrt( 0.299*R^2 + 0.587*G^2 + 0.114*B^2 )

void main()
{
    vec4 color = texture2D(s_postprocess_input, v_texcoord0);
    float luminance = dot(vec3(0.299, 0.587, 0.114), color.rgb);
    gl_FragColor = step(u_bright_threshold.x, luminance) * color;
}