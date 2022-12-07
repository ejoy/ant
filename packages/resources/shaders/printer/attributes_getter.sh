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
    v_normal = normalize(v_normal);

#   ifdef CALC_TBN
    vec3 tangent, bitangent;
    cotangent_frame(v_normal, input_attribs.V, uv, tangent, bitangent);
    input_attribs.N = normal_from_tangent_frame(tangent, bitangent, v_normal, uv);
#   else //!CALC_TBN
    const vec3 tangent = v_tangent, bitangent = v_bitangent;
    input_attribs.N = normal_from_tangent_frame(tangent, bitangent, v_normal, uv);
#   endif //CALC_TBN

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
