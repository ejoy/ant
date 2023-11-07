@FSINPUT_VARYINGS_DEFINE
@FSINPUTOUTPUT_STRUCT

#include <bgfx_shader.sh>
#include <shaderlib.sh>

@FS_PROPERTY_DEFINE
@FS_FUNC_DEFINE

void main()
{
    FSInput fsinput = (FSInput)0;
    FSOutput fsoutput = (FSOutput)0;

    @FSINPUT_INIT

    CUSTOM_FS_FUNC(fsinput, fsoutput);

    gl_FragColor = fsoutput.color;
}