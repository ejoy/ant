{
vs_input.pos = a_position;

#ifdef WITH_COLOR_ATTRIB
	vs_input.color = a_color0;
#endif //WITH_COLOR_ATTRIB

#ifndef MATERIAL_UNLIT
    #ifdef CALC_TBN
        vs_input.normal = a_normal;
    #else    //!CALC_TBN
        vs_input.tangent = a_tangent;
        #ifndef PACK_TANGENT_TO_QUAT
            vs_input.normal = a_normal;
        #endif //PACK_TANGENT_TO_QUAT
    #endif   //CALC_TBN
#endif //MATERIAL_UNLIT

#if defined(GPU_SKINNING) && !defined(USING_LIGHTMAP)
    vs_input.weight = a_weight;
    vs_input.index = a_indices;
#endif

#if defined(USING_LIGHTMAP)
    vs_input.uv1 = a_texcoord1;
#endif //USING_LIGHTMAP

#ifndef WITHOUT_DEFAULT_UV
    vs_input.uv0 = a_texcoord0;
#endif //!WITHOUT_DEFAULT_UV


#ifdef DRAW_INDIRECT
    vs_input.idata0 = i_data0;
    vs_input.idata1 = i_data1;
    vs_input.idata2 = i_data2;
#endif

#ifdef USER0
    vs_input.user0 = a_texcoord2;
#endif //USER0

#ifdef USER1
    vs_input.user1 = a_texcoord3;
#endif //USER1

#ifdef USER2
    vs_input.user2 = a_texcoord4;
#endif //USER2
}