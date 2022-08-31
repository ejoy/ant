#include "common/inputs.sh"

$input v_texcoord0 OUTPUT_WORLDPOS OUTPUT_NORMAL OUTPUT_TANGENT OUTPUT_BITANGENT OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0

#include <bgfx_shader.sh>
#include <bgfx_compute.sh>
#include <shaderlib.sh>
#include "common/camera.sh"

#include "common/transform.sh"
#include "common/utils.sh"
#include "common/cluster_shading.sh"
#include "common/constants.sh"
#include "common/uvmotion.sh"
#include "pbr/ibl.sh"
#include "pbr/lighting.sh"
#include "pbr/pbr.sh"

#ifdef ENABLE_SHADOW
#include "common/shadow.sh"
#define v_distanceVS v_posWS.w
#endif //ENABLE_SHADOW

#include "input_attributes.sh"

void main()
{
#include "attributes_getter.sh"

#ifdef MATERIAL_UNLIT
    gl_FragColor = input_attribs.basecolor + input_attribs.emissive;
#else //!MATERIAL_UNLIT
    material_info mi = init_material_info(input_attribs);

    // LIGHTING
    vec3 color = calc_direct_light(mi, gl_FragCoord, v_posWS.xyz);

#   ifdef ENABLE_SHADOW
	color = shadow_visibility(v_distanceVS, vec4(v_posWS.xyz, 1.0), color);
#   endif //ENABLE_SHADOW

#   ifdef ENABLE_IBL
    color += calc_indirect_light(mi);
#   endif //ENABLE_IBL

#   ifdef HAS_OCCLUSION_TEXTURE
    float ao = texture2D(s_occlusion,  uv).r;
    color  += lerp(color, color * ao, u_occlusion_strength);
#   endif //HAS_OCCLUSION_TEXTURE

#   ifdef ALPHAMODE_MASK
    // Late discard to avoid samplig artifacts. See https://github.com/KhronosGroup/glTF-Sample-Viewer/issues/267
    if(basecolor.a < u_alpha_mask_cutoff)
        discard;
    basecolor.a = 1.0;
#   endif //ALPHAMODE_MASK

    gl_FragColor = vec4(color, input_attribs.basecolor.a) + input_attribs.emissive;
#endif //MATERIAL_UNLIT
}
