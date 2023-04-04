#include "common/inputs.sh"
$input v_texcoord0 OUTPUT_WORLDPOS OUTPUT_NORMAL OUTPUT_TANGENT OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0 OUTPUT_EMISSIVE

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
#define u_building_offset   u_printer_factor.x
#define u_building_topmost  u_printer_factor.y
#include "pbr/input_attributes.sh"

void main()
{ 
    if(v_posWS.y > (u_building_topmost + u_building_offset))
        discard;
    
    #include "pbr/attributes_getter.sh"
    int building;
    if(v_posWS.y > u_building_topmost){
        building = 1;
    } else{
        building = 0;
    }

    if(building || (dot(input_attribs.N, input_attribs.V) < 0)) {
        gl_FragColor = u_construct_color;
    } else {
        gl_FragColor = compute_lighting(input_attribs);
    }
}



