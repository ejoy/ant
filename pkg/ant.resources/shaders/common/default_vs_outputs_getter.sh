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
    v_tangent = vs_output.tangent;
#endif //!MATERIAL_UNLIT   
}