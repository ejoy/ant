#include "default/inputs_define.sh"

$input v_texcoord0 OUTPUT_WORLDPOS OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0 OUTPUT_NORMAL OUTPUT_TANGENT OUTPUT_USER0 OUTPUT_USER1 OUTPUT_USER2 OUTPUT_USER3 OUTPUT_USER4

#include "default/inputs_structure.sh"

$$CUSTOM_FS_PROP$$

$$CUSTOM_FS_FUNC$$

void main()
{
    FSInput fs_input = (FSInput)0;
    FSOutput fs_output = (FSOutput)0;
    #include "default/fs_inputs_getter.sh"

    CUSTOM_FS_FUNC(fs_input, fs_output);

    #include "default/fs_outputs_getter.sh"
}