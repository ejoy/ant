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
#define u_sand_metallic_factor    u_sand_pbr_factor.x
#define u_sand_roughness_factor   u_sand_pbr_factor.y

uniform vec4 u_stone_pbr_factor;
#define u_stone_metallic_factor    u_stone_pbr_factor.x
#define u_stone_roughness_factor   u_stone_pbr_factor.y

uniform vec4 u_cement_pbr_factor;
#define u_cement_metallic_factor    u_cement_pbr_factor.x
#define u_cement_roughness_factor   u_cement_pbr_factor.y

#define sand_alpha          v_idx1.x
#define stone_normal_idx    v_idx1.y
#define terrain_alpha_type  v_idx2.x
#define cement_alpha_type   v_idx2.y
#define sand_color_idx      v_idx2.z
#define stone_color_idx     v_idx2.w

SAMPLER2DARRAY(s_height,             1);
SAMPLER2DARRAY(s_cement_alpha,       3);

vec3 blend(vec4 texture1, float a1, float d1, vec4 texture2, float a2, float d2){
    float depth = 0.03;
    float ma = max(d1 + a1, d2 + a2) - depth;

    float b1 = max(d1  + a1 - ma, 0);
    float b2 = max(d2  + a2 - ma, 0);

    return (texture1.rgb * b1 + texture2.rgb * b2) / (b1 + b2);
}

void main()
{ 
    #ifdef HAS_PROCESSING

    #include "attributes_getter.sh"
    
    vec4 texture_stone   = compute_lighting(stone_attribs);
    vec4 texture_sand    = compute_lighting(sand_attribs);
    vec4 texture_cement  = compute_lighting(cement_attribs);

    float a_sand   = sand_alpha;
    float a_cement = texture2DArray(s_cement_alpha, vec3(v_texcoord1, cement_alpha_type) );
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

       vec4 texture_ground =  vec4(mul(texture_stone.xyz, texture_sand.w) + mul(texture_sand.xyz, 1.0), 1.0);

    if(terrain_alpha_type >= 0.9 && terrain_alpha_type <= 1.1){
        vec4 texture_ground =  vec4(mul(texture_stone.xyz, texture_sand.w) + mul(texture_sand.xyz, 1.0), 1.0);
        gl_FragColor = vec4(blend(texture_cement, 1 - a_cement, d_cement, texture_ground, a_cement, d_stone), 1.0);
        //gl_FragColor = vec4(1 - a_cement > a_cement ? texture_cement.xyz : vec3(0,0,0), 1.0);
    }
    else{
        gl_FragColor = texture_ground;
    }      

/*     vec4 texture_ground =  vec4(mul(stone_attribs.basecolor.xyz, texture_sand.w) + mul(sand_attribs.basecolor.xyz, 1), 1.0);
    if(terrain_alpha_type >= 0.9 && terrain_alpha_type <= 1.1){
        gl_FragColor = vec4(blend(cement_attribs.basecolor, 1 - a_cement, d_cement, texture_ground, a_cement, d_stone), 1.0);
    }
    else{
        gl_FragColor = texture_ground;
    } */  

    //gl_FragColor = vec4(stone_attribs.basecolor.xyz, 1.0);
    //gl_FragColor = vec4(mul(texture_stone.xyz, texture_sand.w) + mul(texture_sand.xyz, 1.0), 1.0);
    //gl_FragColor = vec4(mul(stone_attribs.basecolor.xyz, texture_sand.w) + mul(sand_attribs.basecolor.xyz, 1), 1.0);

    #else
        gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
    #endif
}



