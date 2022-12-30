input_attributes sand_attribs = (input_attributes)0;
input_attributes stone_attribs = (input_attributes)0;
input_attributes cement_attribs = (input_attributes)0;
{
    vec2 uv = uv_motion(v_texcoord2);
    sand_attribs.uv = uv;
    stone_attribs.uv = uv;
    cement_attribs.uv = uv;

    sand_attribs.basecolor   = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), sand_color_idx);
    stone_attribs.basecolor  = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), stone_color_idx);
    if(road_type >= 0.9 && road_type <= 1.1){
        cement_attribs.basecolor = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), 5);
    }
    else if(road_type >= 1.9 && road_type <= 2.1){
        cement_attribs.basecolor = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), 6);
    }
    else if(road_type >= 2.9 && road_type <= 3.1){
        cement_attribs.basecolor = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), 7);
    }

    sand_attribs.emissive   = get_emissive_color(uv);
    stone_attribs.emissive  = get_emissive_color(uv);
    cement_attribs.emissive = get_emissive_color(uv);

#ifndef MATERIAL_UNLIT
    sand_attribs.fragcoord   = gl_FragCoord;
    stone_attribs.fragcoord  = gl_FragCoord;
    cement_attribs.fragcoord = gl_FragCoord;

    sand_attribs.posWS   = v_posWS.xyz;
    stone_attribs.posWS  = v_posWS.xyz;
    cement_attribs.posWS = v_posWS.xyz;

    sand_attribs.distanceVS   = v_posWS.w;
    stone_attribs.distanceVS  = v_posWS.w;
    cement_attribs.distanceVS = v_posWS.w;

    sand_attribs.V   = normalize(u_eyepos.xyz - v_posWS.xyz);
    stone_attribs.V  = normalize(u_eyepos.xyz - v_posWS.xyz);
    cement_attribs.V = normalize(u_eyepos.xyz - v_posWS.xyz);

    v_normal = normalize(v_normal);
    sand_attribs.gN   = v_normal;
    stone_attribs.gN  = v_normal;
    cement_attribs.gN = v_normal;

#ifdef HAS_NORMAL_TEXTURE
#   ifdef CALC_TBN
    mat3 tbn = cotangent_frame(v_normal, sand_attribs.V, uv);
#   else //!CALC_TBN
    v_tangent = normalize(v_tangent);
    vec3 bitangent = cross(v_normal, v_tangent);
    mat3 tbn = mat3(v_tangent, bitangent, v_normal);
#   endif //CALC_TBN
    sand_attribs.N   = get_terrain_normal_by_tbn(tbn, v_normal, uv, 0);
    stone_attribs.N  = get_terrain_normal_by_tbn(tbn, v_normal, uv, stone_normal_idx);
    cement_attribs.N = get_terrain_normal_by_tbn(tbn, v_normal, uv, 3);
#else  //!HAS_NORMAL_TEXTURE
    sand_attribs.N   = v_normal;
    stone_attribs.N  = v_normal;
    cement_attribs.N = v_normal;
#endif //HAS_NORMAL_TEXTURE

#ifdef ENABLE_BENT_NORMAL
    const vec3 bent_normalTS = vec3(0.0, 0.0, 1.0);
    sand_attribs.bent_normal   = bent_normalTS;
    stone_attribs.bent_normal  = bent_normalTS;
    cement_attribs.bent_normal = bent_normalTS;
#endif //ENABLE_BENT_NORMAL

    sand_attribs.metallic = u_sand_metallic_factor;
    sand_attribs.perceptual_roughness = u_sand_roughness_factor;
    sand_attribs.perceptual_roughness  = clamp(sand_attribs.perceptual_roughness, 0.0, 1.0);
    sand_attribs.metallic              = clamp(sand_attribs.metallic, 0.0, 1.0);
    stone_attribs.metallic = u_stone_metallic_factor;
    stone_attribs.perceptual_roughness = u_stone_roughness_factor;
    stone_attribs.perceptual_roughness  = clamp(stone_attribs.perceptual_roughness, 0.0, 1.0);
    stone_attribs.metallic              = clamp(stone_attribs.metallic, 0.0, 1.0);
    cement_attribs.metallic = u_cement_metallic_factor;
    cement_attribs.perceptual_roughness = u_cement_roughness_factor;
    cement_attribs.perceptual_roughness  = clamp(cement_attribs.perceptual_roughness, 0.0, 1.0);
    cement_attribs.metallic              = clamp(cement_attribs.metallic, 0.0, 1.0);        


    get_occlusion(uv, sand_attribs);
    get_occlusion(uv, stone_attribs);
    get_occlusion(uv, cement_attribs);
#endif //!MATERIAL_UNLIT

    sand_attribs.screen_uv   = get_normalize_fragcoord(gl_FragCoord.xy);
    stone_attribs.screen_uv  = get_normalize_fragcoord(gl_FragCoord.xy);
    cement_attribs.screen_uv = get_normalize_fragcoord(gl_FragCoord.xy);

    //should discard after all texture sample is done. See https://github.com/KhronosGroup/glTF-Sample-Viewer/issues/267
#ifdef ALPHAMODE_MASK
    if(sand_attribs.basecolor.a < u_alpha_mask_cutoff)
        discard;
    if(stone_attribs.basecolor.a < u_alpha_mask_cutoff)
        discard;
    if(cement_attribs.basecolor.a < u_alpha_mask_cutoff)
        discard;
    sand_attribs.basecolor.a = 1.0;
    stone_attribs.basecolor.a = 1.0;
    cement_attribs.basecolor.a = 1.0;
#endif //ALPHAMODE_MASK
}


