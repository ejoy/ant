@VSINPUT_VARYING_DEFINE
@VSINPUTOUTPUT_STRUCT

#include <bgfx_shader.sh>
#include <shaderlib.sh>
#include "common/transform.sh"
#include "common/common.sh"

@VS_PROPERTY_DEFINE
@VS_FUNC_DEFINE

void main()
{
    VSInput vsinput = (VSInput)0;
    Varyings varyings = (Varyings)0;

    @VSINPUT_INIT

    mat4 worldmat = (mat4)0;
    gl_Position = CUSTOM_VS_POSITION(vsinput, varyings, worldmat);
#ifndef DEPTH_ONLY
    CUSTOM_VS(vsinput, varyings);
#endif //DEPTH_ONLY

    @OUTPUT_VARYINGS
}