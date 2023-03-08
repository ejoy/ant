#include "common/inputs.sh"
$input v_texcoord0 OUTPUT_WORLDPOS OUTPUT_NORMAL OUTPUT_TANGENT OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0

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

uniform vec4 u_construct_color;
uniform vec4 u_printer_factor;
#define u_building_topmost  u_printer_factor.y
#include "pbr/input_attributes.sh"

void main()
{ 
    //TODO: offset should move to u_printer_factor
    const float offset = 0.0;
    if(v_posWS.y > (u_building_topmost + offset))
        discard;
    
    #include "pbr/attributes_getter.sh"
    int building;
    if(v_posWS.y < u_building_topmost){
        //vec4 c = texture2D(s_basecolor, v_texcoord0) * u_basecolor_factor;
        //input_attribs.basecolor = c;
        building = 0;
    } else{
        input_attribs.basecolor = u_construct_color;
        building = 1;
    }

    if(building || (dot(input_attribs.N, input_attribs.V) < 0)) {
        gl_FragColor = u_construct_color;
    } else {
        gl_FragColor = compute_lighting(input_attribs);
    }
}



