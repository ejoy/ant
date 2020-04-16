$input v_texcoord0

#include <bgfx_shader.sh>
#include <shader_lib.sh>

#include "common/postprocess.sh"

// we need HDR in our render pipeline!
void main()
{
    vec4 scenecolor = toLinear(texture2D(s_mainview,v_texcoord0));
    vec4 bloomcolor = texture2D(s_postprocess_input,v_texcoord0);

    gl_FragColor.rgb    = scenecolor.rgb + bloomcolor.rgb;
    gl_FragColor.a      = scenecolor.a;
}