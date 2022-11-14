vec2 uv        = uv_motion(v_texcoord2);
const mat3 tbn = mtxFromCols(v_tangent, v_bitangent, v_normal);  
vec3 V         = normalize(u_eyepos.xyz - v_posWS.xyz);
vec2 screen_uv = get_normalize_fragcoord(gl_FragCoord.xy);

input_attributes sand_attribs = (input_attributes)0;
{
    sand_attribs.uv = uv;
    sand_attribs.basecolor = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), sand_color_idx);
    sand_attribs.V = V;

    sand_attribs.N = get_terrain_normal_by_tbn(tbn, v_normal, uv, 0);

    sand_attribs.metallic = u_sand_metallic_factor;
    sand_attribs.perceptual_roughness = u_sand_roughness_factor;
    sand_attribs.perceptual_roughness  = clamp(sand_attribs.perceptual_roughness, 0.0, 1.0);
    sand_attribs.metallic              = clamp(sand_attribs.metallic, 0.0, 1.0);

    get_occlusion(uv, sand_attribs);

    sand_attribs.screen_uv = screen_uv;
}

input_attributes stone_attribs = (input_attributes)0;
{
    stone_attribs.uv = uv;
    float color_idx;

    stone_attribs.basecolor = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), stone_color_idx);
    stone_attribs.V = V;
    
    stone_attribs.N = get_terrain_normal_by_tbn(tbn, v_normal, uv, stone_normal_idx);

    stone_attribs.metallic = u_stone_metallic_factor;
    stone_attribs.perceptual_roughness = u_stone_roughness_factor;
    stone_attribs.perceptual_roughness  = clamp(stone_attribs.perceptual_roughness, 0.0, 1.0);
    stone_attribs.metallic              = clamp(stone_attribs.metallic, 0.0, 1.0);
    get_occlusion(uv, stone_attribs);

    stone_attribs.screen_uv = screen_uv;
}

input_attributes cement_attribs = (input_attributes)0;
{
    cement_attribs.uv = uv_motion(v_texcoord0);
    cement_attribs.basecolor = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), 5);
    cement_attribs.V = V;

    cement_attribs.N = get_terrain_normal_by_tbn(tbn, v_normal, uv, 3);

    cement_attribs.metallic = u_cement_metallic_factor;
    cement_attribs.perceptual_roughness = u_cement_roughness_factor;
    cement_attribs.perceptual_roughness  = clamp(cement_attribs.perceptual_roughness, 0.0, 1.0);
    cement_attribs.metallic              = clamp(cement_attribs.metallic, 0.0, 1.0);

    get_occlusion(uv, cement_attribs);

    cement_attribs.screen_uv = screen_uv;
}
