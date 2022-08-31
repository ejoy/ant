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
    input_attribs.N = get_normal(v_tangent, v_bitangent, v_normal, uv);
#   else //!WITH_TANGENT_ATTRIB
    input_attribs.N = get_normal_by_tbn(tbn_from_world_pos(v_normal, v_posWS.xyz, uv), v_normal, uv);
#   endif //WITH_TANGENT_ATTRIB

    get_metallic_roughness(uv, input_attribs);
    get_occlusion(uv, input_attribs);
#endif //!MATERIAL_UNLIT

    //should discard after all texture sample is done. See https://github.com/KhronosGroup/glTF-Sample-Viewer/issues/267
#ifdef ALPHAMODE_MASK
    if(input_attribs.basecolor.a < u_alpha_mask_cutoff)
        discard;
    input_attribs.basecolor.a = 1.0;
#endif //ALPHAMODE_MASK
}
