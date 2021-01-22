$input a_position, a_color0, a_texcoord0
$output v_texcoord0, v_color0
#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
    vec4 p = transform_ui_point(u_model[0], a_position);
	gl_Position = map_screen_coord_to_ndc(p.xy);//transform_screen_coord_to_ndc(u_model[0], a_position);
    v_texcoord0 = a_texcoord0;
    v_color0    = a_color0;

    #ifdef ENABLE_CLIP_PLANES
    for (int i=0; i<4; ++i){
        gl_ClipDistance[i] = dot(p, u_clip_planes[i]);
    }
    #endif //ENABLE_CLIP_PLANES
}