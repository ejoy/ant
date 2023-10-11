#include "default/inputs_define.sh"

$input a_position a_texcoord0 INPUT_COLOR0 INPUT_NORMAL INPUT_TANGENT INPUT_INDICES INPUT_WEIGHT INPUT_LIGHTMAP_TEXCOORD INPUT_INSTANCE1 INPUT_INSTANCE2 INPUT_INSTANCE3 INPUT_USER0 INPUT_USER1 INPUT_USER2
$output v_texcoord0 OUTPUT_WORLDPOS OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0 OUTPUT_NORMAL OUTPUT_TANGENT OUTPUT_BITANGENT OUTPUT_USER0 OUTPUT_USER1 OUTPUT_USER2 OUTPUT_USER3 OUTPUT_USER4

#include "default/inputs_structure.sh"

$$CUSTOM_VS_PROP$$

$$CUSTOM_VS_FUNC$$ 

void main()
{
	VSInput vs_input = (VSInput)0;
	#include "default/vs_inputs_getter.sh"

    VSOutput vs_output = (VSOutput)0;
    CUSTOM_VS_FUNC(vs_input, vs_output);

    #include "default/vs_outputs_getter.sh"
}