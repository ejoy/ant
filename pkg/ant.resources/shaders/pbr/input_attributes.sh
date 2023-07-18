#ifndef _PBR_INPUT_ATTRIBUTES_SH_
#define _PBR_INPUT_ATTRIBUTES_SH_

#include "pbr/attribute_define.sh"
#include "pbr/attribute_uniforms.sh"
#include "common/default_inputs_structure.sh"
#include "common/utils.sh"
#include "common/uvmotion.sh"

input_attributes init_input_attributes(vec3 gnormal, vec3 normal, vec4 posWS, vec4 basecolor, vec4 fragcoord, vec4 metallic, vec4 roughness)
{
    input_attributes input_attribs  = (input_attributes)0;
    input_attribs.basecolor         = basecolor;
    input_attribs.posWS             = posWS.xyz;
    input_attribs.distanceVS        = posWS.w;
    input_attribs.V                 = normalize(u_eyepos.xyz - posWS.xyz);
    input_attribs.gN                = gnormal;  //geomtery normal
    input_attribs.N                 = normal;

    input_attribs.perceptual_roughness  = roughness;
    input_attribs.metallic              = metallic;
    input_attribs.occlusion         = 1.0;

    input_attribs.screen_uv         = get_normalize_fragcoord(fragcoord.xy);
    return input_attribs;
}

void build_fs_input_attribs(in FSInput fs_input, inout input_attributes input_attribs)
{
#ifndef WITHOUT_DEFAULT_UV
    vec2 uv = uv_motion(fs_input.uv0);
    input_attribs.uv = uv;
#endif //WITHOUT_DEFAULT_UV

    #ifdef WITH_COLOR_ATTRIB
        input_attribs.basecolor = get_basecolor(uv, fs_input.color);
    #else //!WITH_COLOR_ATTRIB
        input_attribs.basecolor = get_basecolor(uv, vec4_splat(1.0));
    #endif //WITH_COLOR_ATTRIB

        input_attribs.emissive = get_emissive_color(uv);

    #ifndef MATERIAL_UNLIT
        input_attribs.fragcoord = fs_input.frag_coord;
        input_attribs.posWS = fs_input.pos.xyz;
        input_attribs.distanceVS = fs_input.pos.w;
        input_attribs.V = normalize(u_eyepos.xyz - fs_input.pos.xyz);
        fs_input.normal = normalize(fs_input.normal);
        input_attribs.gN = fs_input.normal;

    #ifdef HAS_NORMAL_TEXTURE
    #   ifdef CALC_TBN
        mat3 tbn = cotangent_frame(fs_input.normal, input_attribs.V, uv);
    #   else //!CALC_TBN
        fs_input.tangent = normalize(fs_input.tangent);
        vec3 bitangent = cross(fs_input.normal, fs_input.tangent);
        mat3 tbn = mat3(fs_input.tangent, bitangent, fs_input.normal);
    #   endif //CALC_TBN
        input_attribs.N = normal_from_tangent_frame(tbn, uv);
    #else  //!HAS_NORMAL_TEXTURE
        input_attribs.N = fs_input.normal;
    #endif //HAS_NORMAL_TEXTURE

    #ifdef ENABLE_BENT_NORMAL
        const vec3 bent_normalTS = vec3(0.0, 0.0, 1.0);
        input_attribs.bent_normal = bent_normalTS;
    #endif //ENABLE_BENT_NORMAL

        get_metallic_roughness(uv, input_attribs);
        get_occlusion(uv, input_attribs);
    #endif //!MATERIAL_UNLIT

        input_attribs.screen_uv = get_normalize_fragcoord(fs_input.frag_coord.xy);

        //should discard after all texture sample is done. See https://github.com/KhronosGroup/glTF-Sample-Viewer/issues/267
    #ifdef ALPHAMODE_MASK
        if(input_attribs.basecolor.a < u_alpha_mask_cutoff)
            discard;
        input_attribs.basecolor.a = 1.0;
    #endif //ALPHAMODE_MASK
}

#endif //_PBR_INPUT_ATTRIBUTES_SH_