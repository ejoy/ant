#define NEW_LIGHTING
#include "common/inputs.sh"
$input v_texcoord0 v_texcoord1 v_texcoord2 v_texcoord3 v_texcoord4 v_normal v_tangent v_bitangent v_posWS v_idx1 v_idx2

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

SAMPLER2DARRAY(s_basecolor,     0);
SAMPLER2DARRAY(s_height,        1);
SAMPLER2DARRAY(s_normal,        2);
SAMPLER2DARRAY(s_cement_alpha,  3);

uniform vec4 u_metallic_roughness_factor1;
uniform vec4 u_metallic_roughness_factor2;
#define u_sand_metallic_factor      u_metallic_roughness_factor1.x
#define u_sand_roughness_factor     u_metallic_roughness_factor1.y

#define u_stone_metallic_factor     u_metallic_roughness_factor1.z
#define u_stone_roughness_factor    u_metallic_roughness_factor1.w

#define u_cement_metallic_factor    u_metallic_roughness_factor2.x
#define u_cement_roughness_factor   u_metallic_roughness_factor2.y

#define v_sand_alpha          v_idx1.x
#define v_stone_normal_idx    v_idx1.y
#define v_road_type           v_idx2.x
#define v_road_shape          v_idx2.y
#define v_sand_color_idx      v_idx2.z
#define v_stone_color_idx     v_idx2.w


mediump vec3 terrain_normal_from_tangent_frame(mat3 tbn, mediump vec2 texcoord, mediump float normal_idx)
{
	mediump vec3 normalTS = texture2DArray(s_normal, mediump vec3(texcoord, normal_idx) );
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

float which_cement_color_idx(float rtype)
{
    if(0.9 <= rtype && rtype <= 1.1){
        return 5.0;
    }
    
    if(1.9 <= rtype && rtype <= 2.1){
        return 6.0;
    }
    
    if(2.9 <= rtype && rtype <= 3.1){
        return 7.0;
    }

    return -1.0;
}

input_attributes init_input_attributes(vec3 gnormal, vec3 normal, vec4 posWS, vec4 basecolor)
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
    return input_attribs;
}

vec3 calc_terrain_color(float cement_color_idx, vec3 cement_basecolor, float cement_alpha, float cement_height,
    vec3 ground_color, float stone_height)
{
    if(cement_color_idx == 5.0) {
        return blend(cement_basecolor, 1.0 - cement_alpha, cement_height, ground_color, cement_alpha, stone_height);
    } else if(cement_color_idx == 6.0 || cement_color_idx == 7.0){
        return cement_height < 1.0 ? cement_basecolor : ground_color;
    } else {
        return ground_color;
    }
}

vec3 blend_ground_color(vec3 sand_basecolor, vec3 stnoe_basecolor, float sand_height, float sand_alpha)
{
    float sand_weight = 4 * abs(sand_height - sand_alpha);
    return stnoe_basecolor*sand_weight + sand_basecolor;
}

void main()
{ 
#ifdef HAS_MULTIPLE_LIGHTING

    #include "attributes_getter.sh"
    
    vec4 stnoe_basecolor   = compute_lighting(stone_attribs);
    vec4 sand_basecolor    = compute_lighting(sand_attribs);
    vec4 cement_basecolor  = compute_lighting(cement_attribs);

    float cement_alpha = texture2DArray(s_cement_alpha, vec3(v_texcoord1, v_road_shape) );
    //terrain's basecolor height should use v_texcoord2, represent 4x4 grid per texture
    float sand_height   = texture2DArray(s_height, vec3(v_texcoord2, 0.0) );
    float stone_height  = texture2DArray(s_height, vec3(v_texcoord2, 1.0) );

    //road's basecolor height should use v_texcoord0, represent 1x1 grid per texture
    float cement_height = texture2DArray(s_height, vec3(v_texcoord0, 2.0) );

    vec3 ground_color = blend_ground_color(sand_basecolor.rgb, stnoe_basecolor.rgb, sand_height, v_sand_alpha);

    if(0.9 <= v_road_type && v_road_type <= 1.1){
        gl_FragColor = vec4(blend(cement_basecolor.rgb, 1.0 - cement_alpha, cement_height, ground_color, cement_alpha, stone_height), 1.0);
    } else if((1.9 <= v_road_type && v_road_type <= 2.1) || (2.9 <= v_road_type && v_road_type <= 3.1)){
        gl_FragColor = cement_height < 1.0 ? cement_basecolor : vec4(ground_color, 1.0);
    } else{
        gl_FragColor = vec4(ground_color, 1.0);
    }
#else   //HAS_MULTIPLE_LIGHTING
    const vec2 uv = v_texcoord2;
    vec4 stnoe_basecolor   = texture2DArray(s_basecolor, vec3(uv, v_stone_color_idx));
    vec4 sand_basecolor    = texture2DArray(s_basecolor, vec3(uv, v_sand_color_idx));

    const float cement_color_idx = which_cement_color_idx(v_road_type);
    vec4 cement_basecolor = vec4_splat(0.0);
    if (cement_color_idx > 0){
        cement_basecolor = texture2DArray(s_basecolor, vec3(uv, cement_color_idx));
    }

    float cement_alpha = texture2DArray(s_cement_alpha, vec3(v_texcoord1, v_road_shape) );
    //terrain's basecolor height should use v_texcoord2, represent 4x4 grid per texture
    float sand_height   = texture2DArray(s_height, vec3(v_texcoord2, 0.0) );
    float stone_height  = texture2DArray(s_height, vec3(v_texcoord2, 1.0) );

    //road's basecolor height should use v_texcoord0, represent 1x1 grid per texture
    float cement_height = texture2DArray(s_height, vec3(v_texcoord0, 2.0) );

    vec3 ground_color = blend_ground_color(sand_basecolor.rgb, stnoe_basecolor.rgb, sand_height, v_sand_alpha);

    vec3 basecolor = calc_terrain_color(cement_color_idx, cement_basecolor, cement_alpha, cement_height, ground_color, stone_height);

    v_normal = normalize(v_normal);
    v_tangent = normalize(v_tangent);
    vec3 bitangent = cross(v_normal, v_tangent);
    mat3 tbn = mat3(v_tangent, bitangent, v_normal);
    vec3 normal = terrain_normal_from_tangent_frame(tbn, uv, v_stone_normal_idx);

    input_attributes input_attribs = init_input_attributes(v_normal, normal, v_posWS, vec4(basecolor, 1.0));

    gl_FragColor = compute_lighting(input_attribs);
        
#endif  //HAS_MULTIPLE_LIGHTING
}



