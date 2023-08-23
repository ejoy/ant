
{
    fs_input.frag_coord = gl_FragCoord;
    fs_input.uv0 = v_texcoord0;
#ifndef MATERIAL_UNLIT
    fs_input.normal = v_normal;
    fs_input.pos    = v_posWS;
    #ifdef WITH_TANGENT_ATTRIB
        fs_input.tangent = v_tangent;
    #endif
#endif //MATERIAL_UNLIT

#ifdef WITH_COLOR_ATTRIB
    fs_input.color = v_color0;
#endif //WITH_COLOR_ATTRIB

#if defined(USING_LIGHTMAP)
    fs_input.uv1 = v_texcoord1;
#endif //USING_LIGHTMAP

#ifdef OUTPUT_USER_ATTR_0
    fs_input.user0 = v_texcoord2;
#endif

#ifdef OUTPUT_USER_ATTR_1
    fs_input.user1 = v_texcoord3;
#endif

#ifdef OUTPUT_USER_ATTR_2
    fs_input.user2 = v_texcoord4;
#endif

#ifdef OUTPUT_USER_ATTR_3
    fs_input.user3 = v_texcoord5;
#endif

#ifdef OUTPUT_USER_ATTR_4
    fs_input.user4 = v_texcoord6;
#endif
}