#ifdef GPU_SKINNING

#ifdef BGFX_SHADER_H_HEADER_GUARD
#error "input.sh file should define before bgfx_shader.sh"
#endif //BGFX_SHADER_H_HEADER_GUARD

#define BGFX_CONFIG_MAX_BONES 128
#define DEFAULT_SKINNING_INPUTS $input a_position, a_indices, a_weight

#else //!GPU_SKINNING

#define DEFAULT_SKINNING_INPUTS $input a_position
#endif //GPU_SKINNING

#define DEF_SKINNING_INPUTS0()                      DEFAULT_SKINNING_INPUTS
#define DEF_SKINNING_INPUTS1(_ARG1)                 DEFAULT_SKINNING_INPUTS, _ARG1
#define DEF_SKINNING_INPUTS2(_ARG1, _ARG2)          DEFAULT_SKINNING_INPUTS, _ARG1, _ARG2
#define DEF_SKINNING_INPUTS3(_ARG1, _ARG2, _ARG3)   DEFAULT_SKINNING_INPUTS, _ARG1, _ARG2, _ARG3
