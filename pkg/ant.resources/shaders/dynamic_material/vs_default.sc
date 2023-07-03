#include "common/default_inputs_define.sh"

$input a_position a_texcoord0 INPUT_COLOR0 INPUT_NORMAL INPUT_TANGENT INPUT_INDICES INPUT_WEIGHT INPUT_LIGHTMAP_TEXCOORD INPUT_INSTANCE1 INPUT_INSTANCE2 INPUT_INSTANCE3 INPUT_USER0 INPUT_USER1 INPUT_USER2
$output v_texcoord0 OUTPUT_WORLDPOS OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0 OUTPUT_NORMAL OUTPUT_TANGENT OUTPUT_USER0 OUTPUT_USER1 OUTPUT_USER2 OUTPUT_USER3 OUTPUT_USER4

#include "common/default_inputs_structure.sh"

$$CUSTOM_VS_FUNC$$

void main()
{
    VSInput vs_input = (VSInput)0;
    VSOutput vs_output = (VSOutput)0;
    #include "common/default_vs_inputs_getter.sh"

    CUSTOM_VS_FUNC(vs_input, vs_output);

    #include "common/default_vs_outputs_getter.sh"
}