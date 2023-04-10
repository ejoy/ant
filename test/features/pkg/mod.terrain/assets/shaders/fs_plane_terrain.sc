#define NEW_LIGHTING
#include "common/inputs.sh"
$input v_texcoord0 v_texcoord1 v_texcoord2 v_normal v_tangent v_bitangent v_posWS v_idx1 v_idx2 v_texcoord3

#include <bgfx_shader.sh>
#include <bgfx_compute.sh>
#include <shaderlib.sh>
#include "common/camera.sh"

#include "common/transform.sh"
#include "common/utils.sh"
#include "common/cluster_shading.sh"
#include "common/constants.sh"
#include "common/uvmotion.sh"
#include "pbr/lighting.sh"
#include "pbr/indirect_lighting.sh"
#include "pbr/pbr.sh"

#define v_distanceVS v_posWS.w
#ifdef ENABLE_SHADOW
#include "common/shadow.sh"
#endif //ENABLE_SHADOW

#include "pbr/attribute_define.sh"

SAMPLER2DARRAY(s_basecolor,             0);
SAMPLER2DARRAY(s_height,                1);
SAMPLER2DARRAY(s_normal,                2);
SAMPLER2DARRAY(s_mark_alpha,            3);

uniform vec4 u_metallic_roughness_factor1;
uniform vec4 u_metallic_roughness_factor2;
#define u_sand_metallic_factor      u_metallic_roughness_factor1.x
#define u_sand_roughness_factor     u_metallic_roughness_factor1.y

#define u_stone_metallic_factor     u_metallic_roughness_factor1.z
#define u_stone_roughness_factor    u_metallic_roughness_factor1.w

#define u_road_metallic_factor    u_metallic_roughness_factor2.x
#define u_road_roughness_factor   u_metallic_roughness_factor2.y

#define v_sand_alpha          v_idx1.x
#define v_stone_normal_idx    v_idx1.y
#define v_road_type           v_idx2.x
#define v_road_shape          v_idx2.y
#define v_sand_color_idx      v_idx2.z
#define v_stone_color_idx     v_idx2.w
#define v_mark_type           v_idx1.z
#define v_mark_shape          v_idx1.w

vec2 texture2DArrayBc5(sampler2DArray _sampler, vec3 _uv)
{
#if BGFX_SHADER_LANGUAGE_HLSL && BGFX_SHADER_LANGUAGE_HLSL <= 300
	return texture2DArray(_sampler, _uv).yx;
#else
	return texture2DArray(_sampler, _uv).xy;
#endif
}

mediump vec3 terrain_normal_from_tangent_frame(mat3 tbn, mediump vec2 texcoord, mediump float normal_idx)
{
	mediump vec3 normalTS = remap_normal(texture2DArrayBc5(s_normal, mediump vec3(texcoord, normal_idx)));
	// same as: mul(transpose(tbn), normalTS)
    return normalize(mul(normalTS, tbn));
}

vec3 blend(vec3 texture1, float a1, float d1, vec3 texture2, float a2, float d2){
    float depth = 0.03;
    float ma = max(d1 + a1, d2 + a2) - depth;

    float b1 = max(d1  + a1 - ma, 0);
    float b2 = max(d2  + a2 - ma, 0);

    return (texture1.rgb * b1 + texture2.rgb * b2) / (b1 + b2);
}

input_attributes init_input_attributes(vec3 gnormal, vec3 normal, vec4 posWS, vec4 basecolor, vec4 fragcoord)
{
    input_attributes input_attribs  = (input_attributes)0;
    input_attribs.basecolor         = basecolor;
    input_attribs.posWS             = posWS.xyz;
    input_attribs.distanceVS        = posWS.w;
    input_attribs.V                 = normalize(u_eyepos.xyz - posWS.xyz);
    input_attribs.gN                = gnormal;  //geomtery normal
    input_attribs.N                 = normal;

    //use stone setting
    input_attribs.perceptual_roughness  = clamp(u_stone_roughness_factor, 0.0, 1.0);
    input_attribs.metallic              = clamp(u_stone_metallic_factor, 0.0, 1.0);
    input_attribs.occlusion         = 1.0;

    input_attribs.screen_uv         = get_normalize_fragcoord(fragcoord.xy);
    return input_attribs;
}

vec3 calc_road_blend_terrain_color(vec4 road_basecolor, vec3 terrain_color, float road_type)
{
    if(road_basecolor.a == 0)
    {
        return terrain_color;
    }
    else
    {
        vec3 stop_color   = vec3(255/255,  37/255,  37/255);
        vec3 choose_color = vec3(228/255, 228/255, 228/255);
        if(road_type == 1){
            return road_basecolor.rgb;
        }
        else if (road_type == 2){
            return vec3((stop_color.r+road_basecolor.r)*0.5, (stop_color.g+road_basecolor.g)*0.5, (stop_color.b+road_basecolor.b)*0.5);
        }
        else{
            return vec3((choose_color.r+road_basecolor.r)*0.5, (choose_color.g+road_basecolor.g)*0.5, (choose_color.b+road_basecolor.b)*0.5);
        }
    }
}

vec3 calc_all_blend_color(float road_type, vec4 road_basecolor, float mark_type, vec3 mark_basecolor, float mark_alpha, float road_height, vec3 terrain_color, float stone_height)
{

    if(road_type != 0.0 && mark_type != 0.0)
    {
        vec3 tmp_color = calc_road_blend_terrain_color(road_basecolor, terrain_color, road_type);
        return blend(mark_basecolor, 1.0 - mark_alpha, road_height, tmp_color, mark_alpha, stone_height); 
    }
    else if(road_type != 0.0 && mark_type == 0.0)
    {
        return calc_road_blend_terrain_color(road_basecolor, terrain_color, road_type);
    }
    else if(road_type == 0.0 && mark_type != 0.0)
    {
        return blend(mark_basecolor, 1.0 - mark_alpha, road_height, terrain_color, mark_alpha, stone_height);
    }
    else
    {
        return terrain_color;
    }
}

vec3 blend_terrain_color(vec3 sand_basecolor, vec3 stone_basecolor, float sand_height, float sand_alpha)
{
    float sand_weight = 4 * abs(sand_height - sand_alpha);
    return stone_basecolor*sand_weight + sand_basecolor;
}

void main()
{ 
    //v_texcoord0 -- road height coordinate 1x1 grid per texture
    //v_texcoord1 -- road color  coordinate 1x1 grid per texture
    //v_texcoord2 -- terrain color/mark color/terrain height coordinate 4x4 grid per texture
    //v_texcoord3 -- mark alpha  coordinate 1x1 grid per texture

#ifdef HAS_MULTIPLE_LIGHTING

    const float road_color_idx = v_road_type;
    
    #include "attributes_getter.sh"
    
    vec4 stone_basecolor   = compute_lighting(stone_attribs);
    vec4 sand_basecolor    = compute_lighting(sand_attribs);
    vec4 road_basecolor  = compute_lighting(road_attribs);

    float road_alpha = texture2DArray(s_road_basecolor, vec3(v_texcoord1, v_road_shape) );
    float road_height = texture2DArray(s_height, vec3(v_texcoord0, 2.0) );
    float sand_height   = texture2DArray(s_height, vec3(v_texcoord1, 0.0) );
    float stone_height  = texture2DArray(s_height, vec3(v_texcoord1, 1.0) );

    vec3 terrain_color = blend_terrain_color(sand_basecolor.rgb, stone_basecolor.rgb, sand_height, v_sand_alpha);

    vec3 color = calc_terrain_color(road_color_idx, road_basecolor, road_alpha, road_height, terrain_color, stone_height);

    gl_FragColor = vec4(color.rgb, 1.0);

#else   
    const vec2 uv = v_texcoord2;
    vec4 stone_basecolor   = texture2DArray(s_basecolor, vec3(uv, v_stone_color_idx));
    vec4 sand_basecolor    = texture2DArray(s_basecolor, vec3(uv, v_sand_color_idx));

    float road_shape_idx = v_road_shape + 4;// 1~7 -> 5~11
    vec4 road_basecolor = texture2DArray(s_basecolor, vec3(v_texcoord1, road_shape_idx));

    float road_height = texture2DArray(s_height, vec3(v_texcoord0, 2.0) );

    float mark_color_idx = v_mark_type + 11; //1~3 -> 12~14
    vec4 mark_basecolor = vec4_splat(0.0);
    mark_basecolor = texture2DArray(s_basecolor, vec3(uv, mark_color_idx));

    float mark_shape_idx = v_mark_shape - 1;// 1~5 -> 0~4
    float mark_alpha = 0;
    
    if(v_mark_type != 0){
        mark_alpha = texture2DArray(s_mark_alpha, vec3(v_texcoord3, mark_shape_idx));
    }   

    float sand_height   = texture2DArray(s_height, vec3(uv, 0.0) );
    float stone_height  = texture2DArray(s_height, vec3(uv, 1.0) );

    vec3 terrain_color = blend_terrain_color(sand_basecolor.rgb, stone_basecolor.rgb, sand_height, v_sand_alpha);

    vec3 basecolor = calc_all_blend_color(v_road_type, road_basecolor, v_mark_type, mark_basecolor, mark_alpha, road_height, terrain_color, stone_height);
    bool is_road_part = v_road_type != 0.0 && road_basecolor.a != 0.0;
    bool is_mark_part = v_mark_type != 0 && mark_alpha != 1;
    if(is_road_part || is_mark_part)
    {
        gl_FragColor = vec4(basecolor, 1.0);
    }
    else
    {
        v_normal = normalize(v_normal);
        v_tangent = normalize(v_tangent);
        vec3 bitangent = cross(v_normal, v_tangent);
        mat3 tbn = mat3(v_tangent, bitangent, v_normal);
        vec3 normal = terrain_normal_from_tangent_frame(tbn, uv, v_stone_normal_idx);

        input_attributes input_attribs = init_input_attributes(v_normal, normal, v_posWS, vec4(basecolor, 1.0), gl_FragCoord);

        gl_FragColor = compute_lighting(input_attribs);

    }
#endif  //HAS_MULTIPLE_LIGHTING
}



