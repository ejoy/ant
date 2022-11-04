input_attributes stone_attribs = (input_attributes)0;
{
    vec2 uv = uv_motion(v_texcoord2);
    stone_attribs.uv = uv;
    float color_idx;

    stone_attribs.basecolor = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), stone_color_idx);
    stone_attribs.V = normalize(u_eyepos.xyz - v_posWS.xyz);

    const mat3 tbn = mtxFromCols(v_tangent, v_bitangent, v_normal);    
    stone_attribs.N = get_terrain_normal_by_tbn(tbn, v_normal, uv, stone_normal_idx);

    stone_attribs.metallic = u_stone_metallic_factor;
    stone_attribs.perceptual_roughness = u_stone_roughness_factor;
    stone_attribs.perceptual_roughness  = clamp(stone_attribs.perceptual_roughness, 0.0, 1.0);
    stone_attribs.metallic              = clamp(stone_attribs.metallic, 0.0, 1.0);
    get_occlusion(uv, stone_attribs);

    stone_attribs.screen_uv = get_normalize_fragcoord(gl_FragCoord.xy);
}
