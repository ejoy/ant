input_attributes sand_attribs = (input_attributes)0;
{
    vec2 uv = uv_motion(v_texcoord2);
    sand_attribs.uv = uv;
    sand_attribs.basecolor = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), sand_color_idx);
    sand_attribs.V = normalize(u_eyepos.xyz - v_posWS.xyz);

    const mat3 tbn = mtxFromCols(v_tangent, v_bitangent, v_normal);

    sand_attribs.N = get_terrain_normal_by_tbn(tbn, v_normal, uv, 0);

    sand_attribs.metallic = u_sand_metallic_factor;
    sand_attribs.perceptual_roughness = u_sand_roughness_factor;
    sand_attribs.perceptual_roughness  = clamp(sand_attribs.perceptual_roughness, 0.0, 1.0);
    sand_attribs.metallic              = clamp(sand_attribs.metallic, 0.0, 1.0);

    get_occlusion(uv, sand_attribs);

    sand_attribs.screen_uv = get_normalize_fragcoord(gl_FragCoord.xy);
}
