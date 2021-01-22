$input a_position, a_texcoord0, a_color0
$output v_color0, v_texcoord0
#include <bgfx_shader.sh>
#include "common/transform.sh"
void main()
{
	vec4 p = transform_ui_point(u_model[0], a_position * 8192.0);
	gl_Position = map_screen_coord_to_ndc(p.xy);
	v_texcoord0 = a_texcoord0;
	v_color0    = a_color0;

	#ifdef ENABLE_CLIP_PLANES
	for (int i=0; i<4; ++i){
		gl_ClipDistance[i] = dot(p, u_clip_planes[i]);
	}
	#endif //ENABLE_CLIP_PLANES
}
