@FSINPUT_VARYINGS_DEFINE
@FSINPUTOUTPUT_STRUCT

#include <bgfx_shader.sh>
#include <shaderlib.sh>

@FS_PROPERTY_DEFINE

#include "common/camera.sh"

#include "common/transform.sh"
#include "common/utils.sh"
#include "common/cluster_shading.sh"
#include "common/constants.sh"
#include "common/uvmotion.sh"
#include "pbr/lighting.sh"
#include "pbr/indirect_lighting.sh"
#include "postprocess/tonemapping.sh"

#include "pbr/material_info.sh"

@FS_FUNC_DEFINE

void main()
{
    Varyings varyings = (Varyings)0;
    FSOutput fsoutput = (FSOutput)0;

@FSINPUT_FROM_VARYING

    CUSTOM_FS(varyings, fsoutput);

    gl_FragColor = fsoutput.color;
}