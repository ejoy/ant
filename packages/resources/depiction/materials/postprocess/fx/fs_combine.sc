$input v_texcoord0

#include <bgfx_shader.sh>
#include "common/postprocess.sh"

// we need HDR in our render pipeline!
void main()
{
    vec4 scenecolor = texture2D(s_mainview,             v_texcoord0);
    vec4 bloomcolor = texture2D(s_postprocess_input,    v_texcoord0);

    vec4 finalcolor = scenecolor + bloomcolor;

    // NOT do tonemapping, just clamp
    gl_FragColor = clamp(finalcolor, vec4_splat(0.0), vec4_splat(1.0));
}