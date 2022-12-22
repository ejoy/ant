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
/*     vec2 uv = uv_motion(v_texcoord2);
    vec4 sand_basecolor   = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), sand_color_idx);
    vec4 stone_basecolor  = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), stone_color_idx);
    vec4 cement_basecolor = get_terrain_basecolor(uv, vec4(1.0, 1.0, 1.0, 1.0), 5);
    const mat3 tbn = mtxFromCols(v_tangent, v_bitangent, v_normal);
    vec4 sand_normal      = vec4(get_terrain_normal_by_tbn(tbn, v_normal, uv, 0), 0);
    vec4 stone_normal     = vec4(get_terrain_normal_by_tbn(tbn, v_normal, uv, stone_normal_idx), 0);
    vec4 cement_normal    = vec4(get_terrain_normal_by_tbn(tbn, v_normal, uv, 3), 0);
    vec4 sand_metallic    = 
    float a_sand   = sand_alpha;
    float a_cement = texture2DArray(s_cement_alpha, vec3(v_texcoord0, cement_alpha_type) );
    float d_sand   = texture2DArray(s_height, vec3(v_texcoord2, 0.0) );
    float d_stone  = texture2DArray(s_height, vec3(v_texcoord2, 1.0) );
    float d_cement = texture2DArray(s_height, vec3(v_texcoord0, 2.0) );

    float sub1 = 4 * abs(d_sand - (a_sand));
    float f1 = 1 - sub1;
    sand_basecolor.w = sub1;
    sand_normal.w    = sub1;

    float sub2 = 4 * abs(d_stone - (1 - a_sand));
    float f2 = 1 - sub2;
    stone_basecolor.w = sub2;
    stone_normal.w    = sub2;

    vec4 ground_basecolor =  vec4(mul(stone_basecolor.xyz, sand_basecolor.w) + mul(sand_basecolor.xyz, 1.0), 1.0);
    vec4 ground_normal    =  vec4(mul(stone_normal.xyz, sand_normal.w) + mul(sand_normal.xyz, 1.0), 1.0);

    vec4 blend_basecolor;
    vec4 blend_normal;

    if(terrain_alpha_type >= 0.9 && terrain_alpha_type <= 1.1){
        blend_basecolor = vec4(blend(cement_basecolor, 1 - a_cement, d_cement, ground_basecolor, a_cement, d_stone), 1.0);
        blend_normal    = vec4(blend(cement_normal, 1 - a_cement, d_cement, ground_normal, a_cement, d_stone), 1.0);
    }
    else{
        blend_basecolor = ground_basecolor;
        blend_normal    = ground_normal;
    } 

    input_attributes blend_attribs = (input_attributes)0;
{
    blend_attribs.uv = uv;
    blend_attribs.basecolor = blend_basecolor;
    blend_attribs.V = normalize(u_eyepos.xyz - v_posWS.xyz);

    blend_attribs.N = blend_normal.xyz;

    blend_attribs.metallic = u_stone_metallic_factor;
    blend_attribs.perceptual_roughness = u_stone_roughness_factor;
    blend_attribs.perceptual_roughness  = clamp(blend_attribs.perceptual_roughness, 0.0, 1.0);
    blend_attribs.metallic              = clamp(blend_attribs.metallic, 0.0, 1.0);

    get_occlusion(uv, blend_attribs);

    blend_attribs.screen_uv = get_normalize_fragcoord(gl_FragCoord.xy);
} 

    gl_FragColor = compute_lighting(blend_attribs, gl_FragCoord, v_posWS, v_normal);
 */

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



