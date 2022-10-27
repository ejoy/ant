input_attributes sand_attribs = (input_attributes)0;
{
    vec2 uv = uv_motion(v_texcoord0);
    sand_attribs.uv = uv;
    sand_attribs.basecolor *= u_basecolor_factor;
    float sand_idx  = v_texcoord1.y;

    if(sand_idx >= 0.9 && sand_idx <= 1.1){
        sand_attribs.basecolor = texture2D(s_sand1_color  ,  v_texcoord0);
    }
    else if(sand_idx >= 1.9 && sand_idx <= 2.1){
        sand_attribs.basecolor = texture2D(s_sand2_color  ,  v_texcoord0);
    }
    else if(sand_idx >= 2.9 && sand_idx <= 3.1){
        sand_attribs.basecolor = texture2D(s_sand3_color  ,  v_texcoord0);
    }

    sand_attribs.emissive = get_emissive_color(uv);

    sand_attribs.V = get_V(u_eyepos.xyz, v_posWS.xyz);

    mat3 tbn = mtxFromCols(v_tangent, v_bitangent, v_normal);
    vec3 normalTS = fetch_bc5_normal(s_sand_normal, v_texcoord0);
    sand_attribs.N = normalize(instMul(normalTS, tbn));

    get_metallic_roughness(uv, sand_attribs);
    get_occlusion(uv, sand_attribs);

}
