#ifdef GPU_SKINNING

#ifdef BGFX_SHADER_H_HEADER_GUARD
#error "input.sh file should define before bgfx_shader.sh"
#endif //BGFX_SHADER_H_HEADER_GUARD

#define BGFX_CONFIG_MAX_BONES 256

#define INPUT_INDICES   a_indices
#define INPUT_WEIGHT    a_weight

#else //!GPU_SKINNING
#define INPUT_INDICES
#define INPUT_WEIGHT
#endif //GPU_SKINNING
