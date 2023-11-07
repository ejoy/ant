@VSINPUT_VARYING_DEFINE
@VSINPUTOUTPUT_STRUCT

#include <bgfx_shader.sh>
#include <shaderlib.sh>

@VS_PROPERTY_DEFINE
@VS_FUNC_DEFINE

void main()
{
    VSInput vsinput = (VSInput)0;
    VSOutput vsoutput = (VSOutput)0;

    @VSINPUT_INIT

    CUSTOM_VS_POSITION(vsinput, vsoutput);
#ifndef DEPTH_ONLY
    CUSTOM_VS(vsinput, vsoutput);
#endif //DEPTH_ONLY

    @OUTPUT_VARYINGS
}