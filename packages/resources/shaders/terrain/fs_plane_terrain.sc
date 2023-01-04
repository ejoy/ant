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

#include "pbr/input_attributes.sh"


uniform vec4 u_sand_pbr_factor;
#define u_sand_metallic_factor      u_sand_pbr_factor.x
#define u_sand_roughness_factor     u_sand_pbr_factor.y
#define u_sand_occlusion_factor     u_sand_pbr_factor.w

uniform vec4 u_stone_pbr_factor;
#define u_stone_metallic_factor     u_stone_pbr_factor.x
#define u_stone_roughness_factor    u_stone_pbr_factor.y
#define u_stone_occlusion_factor    u_stone_pbr_factor.w

uniform vec4 u_cement_pbr_factor;
#define u_cement_metallic_factor    u_cement_pbr_factor.x
#define u_cement_roughness_factor   u_cement_pbr_factor.y
#define u_cement_occlusion_factor   u_cement_pbr_factor.w

#define sand_alpha          v_idx1.x
#define stone_normal_idx    v_idx1.y
#define road_type           v_idx2.x
#define road_shape          v_idx2.y
#define sand_color_idx      v_idx2.z
#define stone_color_idx     v_idx2.w

SAMPLER2DARRAY(s_height,             1);
SAMPLER2DARRAY(s_cement_alpha,       3);

vec3 blend(vec3 texture1, float a1, float d1, vec3 texture2, float a2, float d2){
    float depth = 0.03;
    float ma = max(d1 + a1, d2 + a2) - depth;

    float b1 = max(d1  + a1 - ma, 0);
    float b2 = max(d2  + a2 - ma, 0);

    return (texture1.rgb * b1 + texture2.rgb * b2) / (b1 + b2);
}

void main()
{ 
    #ifdef HAS_MULTIPLE_LIGHTING

    #include "attributes_getter.sh"
    
    vec4 texture_stone   = compute_lighting(stone_attribs);
    vec4 texture_sand    = compute_lighting(sand_attribs);
    vec4 texture_cement  = compute_lighting(cement_attribs);

    float a_sand   = sand_alpha;
    float a_cement = texture2DArray(s_cement_alpha, vec3(v_texcoord1, road_shape) );
    //terrain's basecolor height should use v_texcoord2, represent 4x4 grid per texture
    float d_sand   = texture2DArray(s_height, vec3(v_texcoord2, 0.0) );
    float d_stone  = texture2DArray(s_height, vec3(v_texcoord2, 1.0) );

    //road's basecolor height should use v_texcoord0, represent 1x1 grid per texture
    float d_cement = texture2DArray(s_height, vec3(v_texcoord0, 2.0) );

    float sub1 = 4 * abs(d_sand - (a_sand));
    float f1 = 1 - sub1;
    texture_sand.w = sub1;

    float sub2 = 4 * abs(d_stone - (1 - a_sand));
    float f2 = 1 - sub2;
    texture_stone.w = sub2;   

    vec3 texture_ground =  texture_stone.xyz*texture_sand.w + texture_sand.xyz;

    if(road_type >= 0.9 && road_type <= 1.1){
        gl_FragColor = vec4(blend(texture_cement.rgb, 1 - a_cement, d_cement, texture_ground, a_cement, d_stone), 1.0);
    }
    else if((road_type >= 1.9 && road_type <= 2.1) || (road_type >= 2.9 && road_type <= 3.1)){
        gl_FragColor = a_cement < 1.0 ? texture_cement : vec4(texture_ground, 1.0);
    }
    else{
        gl_FragColor = vec4(texture_ground, 1.0);
    }      
    #else

    #include "attributes_getter.sh"
    
    vec4 texture_stone   = stone_attribs.basecolor;
    vec4 texture_sand    = sand_attribs.basecolor;
    vec4 texture_cement  = cement_attribs.basecolor;

    float a_sand   = sand_alpha;
    float a_cement = texture2DArray(s_cement_alpha, vec3(v_texcoord1, road_shape) );
    //terrain's basecolor height should use v_texcoord2, represent 4x4 grid per texture
    float d_sand   = texture2DArray(s_height, vec3(v_texcoord2, 0.0) );
    float d_stone  = texture2DArray(s_height, vec3(v_texcoord2, 1.0) );

    //road's basecolor height should use v_texcoord0, represent 1x1 grid per texture
    float d_cement = texture2DArray(s_height, vec3(v_texcoord0, 2.0) );

    float sub1 = 4 * abs(d_sand - (a_sand));
    float f1 = 1 - sub1;
    texture_sand.w = sub1;

    float sub2 = 4 * abs(d_stone - (1 - a_sand));
    float f2 = 1 - sub2;
    texture_stone.w = sub2;   

    vec3 texture_ground =  texture_stone.xyz*texture_sand.w + texture_sand.xyz;
     if(road_type >= 0.9 && road_type <= 1.1){
        stone_attribs.basecolor = vec4(blend(texture_cement, 1 - a_cement, d_cement, texture_ground, a_cement, d_stone), 1.0);
        gl_FragColor = compute_lighting(stone_attribs);
    }
    else if((road_type >= 1.9 && road_type <= 2.1) || (road_type >= 2.9 && road_type <= 3.1)){
        stone_attribs.basecolor = a_cement < 1.0 ? texture_cement : vec4(texture_ground, 1.0);
        gl_FragColor = compute_lighting(stone_attribs);
    }
    else{
        stone_attribs.basecolor = vec4(texture_ground, 1.0);
        gl_FragColor = compute_lighting(stone_attribs);
    }          
        
    #endif
}



