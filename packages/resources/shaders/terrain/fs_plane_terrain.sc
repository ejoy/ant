#include "common/inputs.sh"
$input v_texcoord0 v_texcoord1 v_normal v_tangent v_bitangent v_stone_type v_posWS

#include <bgfx_shader.sh>
#include <bgfx_compute.sh>
#include <shaderlib.sh>
#include "common/camera.sh"
#include "common/transform.sh"
#include "terrain_input_attributes.sh"
#include "terrain_material_info.sh"
#include "common/uvmotion.sh"
#include "terrain_lighting.sh"

vec3 blend(vec4 texture1, float a1, float d1, vec4 texture2, float a2, float d2){
    float depth = 0.03;
    float ma = max(d1 + a1, d2 + a2) - depth;

    float b1 = max(d1  + a1 - ma, 0);
    float b2 = max(d2  + a2 - ma, 0);

    return (texture1.rgb * b1 + texture2.rgb * b2) / (b1 + b2);
}

vec4 compute_lighting(input_attributes input_attribs, vec4 FragCoord, vec3 posWS){
    material_info mi = init_material_info(input_attribs);
    vec3 color = calc_direct_light(mi, FragCoord, posWS.xyz);
    //color = apply_occlusion(input_attribs, color);
    return vec4(color, input_attribs.basecolor.a) + input_attribs.emissive;
}

void main()
{ 
    #include "stone_attributes_getter.sh"
    #include "sand_attributes_getter.sh"

    //vec4 texture_stone = compute_lighting(stone_attribs, vec4(1, 1, 1, 1), v_posWS.xyz);
    //vec4 texture_sand  = compute_lighting(sand_attribs, vec4(1, 1, 1, 1), v_posWS.xyz);

    vec4 texture_stone = vec4(stone_attribs.basecolor.xyz, 1.0);
    vec4 texture_sand  = vec4(sand_attribs.basecolor.xyz, 1.0);

    float a_sand  = v_texcoord1.x;
    float d_stone = texture2D(s_stone_height, v_texcoord0);
    float d_sand  = texture2D(s_sand_height , v_texcoord0);

    float sub1 = 4 * abs(d_sand - (a_sand));
    float f1 = 1 - sub1;
    //texture_stone.xyz = mul(texture_stone, f1);
    texture_sand.w = sub1;

    float sub2 = 4 * abs(d_stone - 1);
    float f2 = 1 - sub2;
    //texture_sand.xyz = mul(texture_sand, f2);
    texture_stone.w = sub2;   
    gl_FragColor = vec4(mul(texture_stone.xyz, texture_sand.w) + mul(texture_sand.xyz, 1), 1.0);
    //gl_FragColor = vec4(texture_sand.xyz, 1.0); 

    /*  float a_sand  = v_texcoord1.x;
    float a_sand_stone1 = v_texcoord1.y;
    float a_sand_stone2 = v_texcoord2.x;
    float d_stone;
    float d_sand1  = texture2D(s_sand1_height , v_texcoord0);
    float d_sand2  = texture2D(s_sand2_height , v_texcoord0);

    vec4 texture_stone1 = texture2D(s_stone1_color  ,  v_texcoord0);
    vec4 texture_stone2 = texture2D(s_stone2_color  ,  v_texcoord0);
    vec4 texture_stone3 = texture2D(s_stone3_color  ,  v_texcoord0);
    vec4 texture_sand  = texture2D(s_sand_color   ,  v_texcoord0);
    vec4 texture_sand_stone1  = texture2D(s_sand_stone1_color   ,  v_texcoord0);
    vec4 texture_sand_stone2  = texture2D(s_sand_stone2_color   ,  v_texcoord0);

    vec4 texture_t1;
    if(v_dtype >= 0.9 && v_dtype <= 1.1){
        texture_t1 = vec4(texture_stone1.rgb, 1.0);
        d_stone = texture2D(s_stone1_height  , v_texcoord0);
    }
    else if(v_dtype >= 1.9 && v_dtype <= 2.1){
        texture_t1 = vec4(texture_stone2.rgb, 1.0);
        d_stone = texture2D(s_stone2_height  , v_texcoord0);
    }
    else{
        texture_t1 = vec4(texture_stone3.rgb, 1.0);
        d_stone = texture2D(s_stone3_height  , v_texcoord0);
    }


    d_stone = texture2D(s_stone1_height  , v_texcoord0); */
    //gl_FragColor     = vec4(blend(texture_stone1, 1 - a_sand , d_stone, texture_sand, a_sand, d_sand1), 1.0);

    /*
    vec4 sc = vec4(1 - a_sand, a_sand, 0, 0);
    vec4 bl = vec4(d_stone + sc.x, d_sand1 + sc.y, 0, 0);
    float a = maximized(bl);
    bl = normalized(max(bl - a + 0.1, 0));

    vec3 col;
    col  = bl.x * texture_stone1.rgb + bl.y * texture_sand.rgb;
    gl_FragColor = vec4(col * (sc.x + sc.y), 1.0);
    */
}



