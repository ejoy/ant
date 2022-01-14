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

#ifdef WITH_COLOR_ATTRIB
#   define INPUT_COLOR0    a_color0
#   define OUTPUT_COLOR0   v_color0
#else //!WITH_COLOR_ATTRIB
#   define INPUT_COLOR0
#   define OUTPUT_COLOR0
#endif //WITH_COLOR_ATTRIB

#ifndef WITH_TANGENT_ATTRIB
#if !(defined(CALC_TBN) || defined(WITHOUT_TANGENT_ATTRIB))
#define WITH_TANGENT_ATTRIB 1
#endif 
#endif //!WITH_TANGENT_ATTRIB

#ifdef WITH_TANGENT_ATTRIB
#   define INPUT_TANGENT    a_tangent
#   define OUTPUT_TANGENT   v_tangent
#   define OUTPUT_BITANGENT v_bitangent
#else //!WITH_TANGENT_ATTRIB
#   define INPUT_TANGENT
#   define OUTPUT_TANGENT
#   define OUTPUT_BITANGENT
#endif//WITH_TANGENT_ATTRIB

#if defined(USING_LIGHTMAP)
#   define INPUT_LIGHTMAP_TEXCOORD      a_texcoord1
#   define OUTPUT_LIGHTMAP_TEXCOORD     v_texcoord1
#else //!USING_LIGHTMAP
#   define INPUT_LIGHTMAP_TEXCOORD
#   define OUTPUT_LIGHTMAP_TEXCOORD
#endif //USING_LIGHTMAP

#ifdef MATERIAL_UNLIT
#define INPUT_NORMAL
#define OUTPUT_NORMAL
#define OUTPUT_WORLDPOS
#else //!MATERIAL_UNLIT
#define INPUT_NORMAL a_normal
#define OUTPUT_NORMAL v_normal
#define OUTPUT_WORLDPOS v_posWS
#endif //MATERIAL_UNLIT