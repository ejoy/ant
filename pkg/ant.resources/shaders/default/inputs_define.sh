#ifdef BGFX_SHADER_H_HEADER_GUARD
#error "'default_inputs_define.sh' file should define before bgfx_shader.sh"
#endif //BGFX_SHADER_H_HEADER_GUARD

#define INPUT_INSTANCE1
#define INPUT_INSTANCE2
#define INPUT_INSTANCE3

#ifdef DRAW_INDIRECT
    #if DRAW_INDIRECT > 0
        #undef INPUT_INSTANCE1
        #define INPUT_INSTANCE1 i_data0
    #elif DRAW_INDIRECT > 1
        #undef INPUT_INSTANCE2
        #define INPUT_INSTANCE2 i_data1
    #elif DRAW_INDIRECT > 2
        #undef INPUT_INSTANCE3
        #define INPUT_INSTANCE3 i_data2
    #endif // CHECK DRAW_INDIRECT NUM
#endif //DRAW_INDIRECT

#ifdef CS_SKINNING

    #   define INPUT_INDICES
    #   define INPUT_WEIGHT

#else //!CS_SKINNING

    #ifdef GPU_SKINNING
    #   define BGFX_CONFIG_MAX_BONES 64

    #   define INPUT_INDICES a_indices
    #   define INPUT_WEIGHT a_weight

    #else //!GPU_SKINNING
    #   define BGFX_CONFIG_MAX_BONES 1

    #   define INPUT_INDICES
    #   define INPUT_WEIGHT
    #endif //GPU_SKINNING

#endif //CS_SKINNING

#ifdef WITH_COLOR_ATTRIB
#   define INPUT_COLOR0    a_color0
#   define OUTPUT_COLOR0   v_color0
#else //!WITH_COLOR_ATTRIB

#   define INPUT_COLOR0

#   ifdef WITH_CUSTOM_COLOR0_ATTRIB
#   define OUTPUT_COLOR0 v_color0
#   else //!WITH_CUSTOM_COLOR0_ATTRIB
#   define OUTPUT_COLOR0
#   endif //WITH_CUSTOM_COLOR0_ATTRIB

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

#if PACK_TANGENT_TO_QUAT && !defined(WITH_TANGENT_ATTRIB)
#define WITH_TANGENT_ATTRIB 1
#endif //PACK_TANGENT_TO_QUAT && !defined(WITH_TANGENT_ATTRIB)

#ifdef MATERIAL_UNLIT
#   define INPUT_NORMAL
#   define INPUT_TANGENT

#   define OUTPUT_NORMAL
#   define OUTPUT_TANGENT

#   define OUTPUT_WORLDPOS

#else //!MATERIAL_UNLIT

#   ifdef WITH_NORMAL_ATTRIB
#   define INPUT_NORMAL     a_normal
#   else
#   define INPUT_NORMAL
#   endif

#   ifdef WITH_TANGENT_ATTRIB
#   define INPUT_TANGENT      a_tangent
#   else
#   define INPUT_TANGENT
#   endif

#if defined(WITH_TANGENT_ATTRIB) || defined(WITH_CUSTOM_TANGENT_ATTRIB)
#   define OUTPUT_TANGENT     v_tangent
#   define OUTPUT_BITANGENT   v_bitangent
#   else
#   define OUTPUT_TANGENT
#   define OUTPUT_BITANGENT
#endif

#   define OUTPUT_NORMAL    v_normal
#   define OUTPUT_WORLDPOS  v_posWS

#endif //MATERIAL_UNLIT

#ifdef INPUT_USER_ATTR_0
    #define INPUT_USER0 a_texcoord2
#else //!INPUT_USER_ATTR_0
    #define INPUT_USER0
#endif //INPUT_USER_ATTR_0

#ifdef INPUT_USER_ATTR_1
    #define INPUT_USER1 a_texcoord3
#else //!INPUT_USER_ATTR_1
    #define INPUT_USER1
#endif //INPUT_USER_ATTR_1

#ifdef INPUT_USER_ATTR_2
    #define INPUT_USER2 a_texcoord4
#else //!INPUT_USER_ATTR_2
    #define INPUT_USER2
#endif //INPUT_USER_ATTR_2

#ifdef OUTPUT_USER_ATTR_0
    #define OUTPUT_USER0 v_texcoord2
#else //!OUTPUT_USER_ATTR_0
    #define OUTPUT_USER0
#endif //OUTPUT_USER_ATTR_0

#ifdef OUTPUT_USER_ATTR_1
    #define OUTPUT_USER1 v_texcoord3
#else //!OUTPUT_USER_ATTR_1
    #define OUTPUT_USER1
#endif //OUTPUT_USER_ATTR_1

#ifdef OUTPUT_USER_ATTR_2
    #define OUTPUT_USER2 v_texcoord4
#else //!OUTPUT_USER_ATTR_2
    #define OUTPUT_USER2
#endif //OUTPUT_USER_ATTR_2

#ifdef OUTPUT_USER_ATTR_3
    #define OUTPUT_USER3 v_texcoord5
#else //!OUTPUT_USER_ATTR_3
    #define OUTPUT_USER3
#endif //OUTPUT_USER_ATTR_3

#ifdef OUTPUT_USER_ATTR_4
    #define OUTPUT_USER4 v_texcoord6
#else //!OUTPUT_USER_ATTR_4
    #define OUTPUT_USER4
#endif //OUTPUT_USER_ATTR_4