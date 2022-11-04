input_attributes input_attribs = (input_attributes)0;
{
    vec2 uv = uv_motion(v_texcoord0);
    input_attribs.uv = uv;
#ifdef WITH_COLOR_ATTRIB
    input_attribs.basecolor = get_basecolor(uv, v_color0);
#else //!WITH_COLOR_ATTRIB
    input_attribs.basecolor = get_basecolor(uv, vec4_splat(1.0));
#endif //WITH_COLOR_ATTRIB

    input_attribs.emissive = get_emissive_color(uv);

#ifndef MATERIAL_UNLIT
    input_attribs.V = normalize(u_eyepos.xyz - v_posWS.xyz);
#   ifdef WITH_TANGENT_ATTRIB
    const mat3 tbn = mtxFromCols(v_tangent, v_bitangent, v_normal);
#   else //!WITH_TANGENT_ATTRIB
    const mat3 tbn = tbn_from_world_pos(v_normal, v_posWS.xyz, uv);
#   endif //WITH_TANGENT_ATTRIB

    input_attribs.N = get_normal_by_tbn(tbn, v_normal, uv);

#ifdef ENABLE_BENT_NORMAL
    const vec3 bent_normalTS = vec3(0.0, 0.0, 1.0);
    input_attribs.bent_normal = instMul(bent_normalTS, tbn);
#endif //ENABLE_BENT_NORMAL

    get_metallic_roughness(uv, input_attribs);
    get_occlusion(uv, input_attribs);
#endif //!MATERIAL_UNLIT

    input_attribs.screen_uv = get_normalize_fragcoord(gl_FragCoord.xy);

    //should discard after all texture sample is done. See https://github.com/KhronosGroup/glTF-Sample-Viewer/issues/267
#ifdef ALPHAMODE_MASK
    if(input_attribs.basecolor.a < u_alpha_mask_cutoff)
        discard;
    input_attribs.basecolor.a = 1.0;
#endif //ALPHAMODE_MASK
}
