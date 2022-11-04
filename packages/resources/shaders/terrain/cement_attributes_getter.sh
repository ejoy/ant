input_attributes cement_attribs = (input_attributes)0;
{
    vec2 uv = uv_motion(v_texcoord2);
    cement_attribs.uv = uv;
    cement_attribs.basecolor = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), 5);
    cement_attribs.V = normalize(u_eyepos.xyz - v_posWS.xyz);

    const mat3 tbn = mtxFromCols(v_tangent, v_bitangent, v_normal);

    cement_attribs.N = get_terrain_normal_by_tbn(tbn, v_normal, uv, 3);

    cement_attribs.metallic = u_cement_metallic_factor;
    cement_attribs.perceptual_roughness = u_cement_roughness_factor;
    cement_attribs.perceptual_roughness  = clamp(cement_attribs.perceptual_roughness, 0.0, 1.0);
    cement_attribs.metallic              = clamp(cement_attribs.metallic, 0.0, 1.0);

    get_occlusion(uv, cement_attribs);

    cement_attribs.screen_uv = get_normalize_fragcoord(gl_FragCoord.xy);
}
