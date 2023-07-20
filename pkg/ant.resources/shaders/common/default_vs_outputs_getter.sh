{
    gl_Position = vs_output.clip_pos;

    v_texcoord0	=  vs_output.uv0;

#ifdef USING_LIGHTMAP
    v_texcoord1 = vs_output.uv1;
#endif //USING_LIGHTMAP

#ifdef WITH_COLOR_ATTRIB
    v_color0= vs_output.color;
#endif //WITH_COLOR_ATTRIB

#ifndef MATERIAL_UNLIT
    v_posWS = vs_output.world_pos;
    v_normal = vs_output.normal;
    #if defined(WITH_TANGENT_ATTRIB) || defined(WITH_CUSTOM_TANGENT_ATTRIB)
        v_tangent = vs_output.tangent;
    #endif
#endif //!MATERIAL_UNLIT  

#ifdef OUTPUT_USER_ATTR_0
    v_texcoord2 = vs_output.user0;
#endif 

#ifdef OUTPUT_USER_ATTR_1
    v_texcoord3 = vs_output.user1;
#endif

#ifdef OUTPUT_USER_ATTR_2
    v_texcoord4 = vs_output.user2;
#endif

#ifdef OUTPUT_USER_ATTR_3
    v_texcoord5 = vs_output.user3;
#endif

#ifdef OUTPUT_USER_ATTR_4
    v_texcoord6 = vs_output.user4;
#endif


}