input_attributes stone_attribs = (input_attributes)0;
{
    vec2 uv = uv_motion(v_texcoord0);
    stone_attribs.uv = uv;
    stone_attribs.basecolor *= u_basecolor_factor;
    float stone_idx = v_stone_type;
    vec3 normalTS;

    if(stone_idx >= 0.9 && stone_idx <= 1.1){
        stone_attribs.basecolor = texture2D(s_stone1_color  ,  v_texcoord0);
        normalTS = fetch_bc5_normal(s_stone1_normal, v_texcoord0);
    }
    else if(stone_idx >= 1.9 && stone_idx <= 2.1){
        stone_attribs.basecolor = texture2D(s_stone2_color  ,  v_texcoord0);
        normalTS = fetch_bc5_normal(s_stone2_normal, v_texcoord0);
    }

    stone_attribs.emissive = get_emissive_color(uv);

    stone_attribs.V = get_V(u_eyepos.xyz, v_posWS.xyz);

    mat3 tbn = mtxFromCols(v_tangent, v_bitangent, v_normal);
    stone_attribs.N = normalize(instMul(normalTS, tbn));

    get_metallic_roughness(uv, stone_attribs);
    get_occlusion(uv, stone_attribs);

}
