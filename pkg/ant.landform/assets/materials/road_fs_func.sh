// already move to road.lua
// vec3 calc_road_basecolor(vec3 road_basecolor, int road_type)
// {
//     vec3 stop_color   = vec3(255.0/255,  37.0/255,  37.0/255);
//     vec3 choose_color = vec3(228.0/255, 228.0/255, 228.0/255);
//     vec3 colors[] = {
//         road_basecolor,
//         (stop_color + road_basecolor) * 0.5,
//         (choose_color + road_basecolor) * 0.5,
//     };
//     return colors[road_type-1];
// }


material_info road_material_info_init(vec3 gnormal, vec3 normal, vec4 posWS, vec4 basecolor, vec4 fragcoord, float metallic, float roughness)
{
    material_info mi  = (material_info)0;
    mi.basecolor         = basecolor;
    mi.posWS             = posWS.xyz;
    mi.distanceVS        = posWS.w;
    mi.V                 = normalize(u_eyepos.xyz - posWS.xyz);
    mi.gN                = gnormal;  //geomtery normal
    mi.N                 = normal;

    mi.perceptual_roughness  = roughness;
    mi.metallic              = metallic;
    mi.occlusion         = 1.0;

    mi.screen_uv         = calc_normalize_fragcoord(fragcoord.xy);
    return mi;
}

void CUSTOM_FS(in Varyings varyings, out FSOutput fsoutput)
{
    const vec2 uv  = varyings.texcoord0;

    const vec4 road_basecolor = texture2D(s_basecolor, uv); 
    const vec3 basecolor = road_basecolor.rgb * varyings.color0.rgb;

    const vec4 mrSample = texture2D(s_metallic_roughness, uv);
    const float roughness = mrSample.g;
    const float metallic = mrSample.b;
    const vec3 normal = vec3(0.0, 1.0, 0.0);
    material_info mi = road_material_info_init(normal, normal, varyings.posWS, vec4(basecolor, road_basecolor.a), varyings.frag_coord, metallic, roughness);
    build_material_info(mi);
    fsoutput.color = compute_lighting(mi);
}