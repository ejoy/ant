VS_Input vsin = (VS_Input)0;
{
    vsin.uv0 = a_texcoord0;
    vsin.uv1 = a_texcoord1;

    vsin.pos = a_position;
    vsin.color = a_color0;
    
#ifdef CALC_TBN
    vsin.normal = a_normal;
#else //!CALC_TBN
    vsin.tangent = a_tangent;
    #ifndef PACK_TANGENT_TO_QUAT
    vsin.normal = a_normal;
    #endif //PACK_TANGENT_TO_QUAT
#endif //CALC_TBN

#ifdef GPU_SKINNING
    vsin.indices = a_indices;
    vsin.weights = a_weight;
#endif //GPU_SKINNING
}