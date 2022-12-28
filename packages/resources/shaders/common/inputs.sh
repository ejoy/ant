#ifdef BGFX_SHADER_H_HEADER_GUARD
#error "input.sh file should define before bgfx_shader.sh"
#endif //BGFX_SHADER_H_HEADER_GUARD

#ifdef GPU_SKINNING
#   define BGFX_CONFIG_MAX_BONES 255

#   define INPUT_INDICES   a_indices
#   define INPUT_WEIGHT    a_weight

#else //!GPU_SKINNING
#   define BGFX_CONFIG_MAX_BONES 1

#   define INPUT_INDICES
#   define INPUT_WEIGHT
#endif //GPU_SKINNING

#ifdef WITH_COLOR_ATTRIB
#   define INPUT_COLOR0    a_color0
#   define OUTPUT_COLOR0   v_color0
#else //!WITH_COLOR_ATTRIB
#   define INPUT_COLOR0
#   define OUTPUT_COLOR0
#endif //WITH_COLOR_ATTRIB

#if defined(USING_LIGHTMAP)
#   define INPUT_LIGHTMAP_TEXCOORD      a_texcoord1
#   define OUTPUT_LIGHTMAP_TEXCOORD     v_texcoord1
#else //!USING_LIGHTMAP
#   define INPUT_LIGHTMAP_TEXCOORD
#   define OUTPUT_LIGHTMAP_TEXCOORD
#endif //USING_LIGHTMAP

#ifndef PACK_TANGENT_TO_QUAT
#define PACK_TANGENT_TO_QUAT 1
#endif //PACK_TANGENT_TO_QUAT

#ifdef MATERIAL_UNLIT
#   define INPUT_NORMAL
#   define INPUT_TANGENT

#   define OUTPUT_NORMAL
#   define OUTPUT_TANGENT
#   define OUTPUT_BITANGENT

#   define OUTPUT_WORLDPOS

#else //!MATERIAL_UNLIT
#   ifdef CALC_TBN
#   define INPUT_NORMAL     a_normal
#   define INPUT_TANGENT

#   define OUTPUT_NORMAL    v_normal
#   define OUTPUT_TANGENT
#   define OUTPUT_BITANGENT
#   else    //!CALC_TBN
#       define INPUT_TANGENT    a_tangent

#       if PACK_TANGENT_TO_QUAT
#       define INPUT_NORMAL
#       else //!PACK_TANGENT_TO_QUAT
#       define INPUT_NORMAL a_normal
#       endif //PACK_TANGENT_TO_QUAT

#       define OUTPUT_NORMAL    v_normal
#       define OUTPUT_TANGENT   v_tangent
#       define OUTPUT_BITANGENT v_bitangent
#   endif   //CALC_TBN

#   define OUTPUT_WORLDPOS v_posWS
#endif //MATERIAL_UNLIT
