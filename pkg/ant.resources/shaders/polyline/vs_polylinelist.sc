#include "polyline/input.sh"

$input a_position, a_texcoord0, a_texcoord1, a_texcoord2
$output v_texcoord0 MASK_UV VELOCITY_CUR_POS VELOCITY_PREV_POS

#include <bgfx_shader.sh>
#include "polyline/polyline.sh"
#ifdef ENABLE_POLYLINE_MASK
#include "polyline/mask.sh"
#endif //ENABLE_POLYLINE_MASK
#include "common/uvmotion.sh"
#include "common/common.sh"
#define a_linedir   a_texcoord2
#ifdef ENABLE_TAA
    uniform mat4 u_prev_mvp;
#endif
void main() {
	float aspect = u_viewRect.z / u_viewRect.w;

	vec4 posCS = mul(u_modelViewProj, vec4(a_position, 1.0));
	vec4 dirCS = mul(u_modelViewProj, vec4(a_linedir, 0.0));

	#ifdef ENABLE_TAA
		vec4 dirCS2 = vec4(0, 0, 0, 0);
		v_prev_pos = mul(u_prev_mvp, vec4(a_position, 1.0));
		dirCS2 = mul(u_prev_mvp, vec4(a_linedir, 0.0));

		float w1 = calc_line_width(posCS.w, a_width, aspect);
		vec2 offset1 = calc_offset(dirCS.xy, aspect, w1);

		float w2 = calc_line_width(v_prev_pos.w, a_width, aspect);
		vec2 offset2 = calc_offset(dirCS2.xy, aspect, w2);

		posCS.xy += offset1 * a_side;
		v_prev_pos.xy += offset2 * a_side;
		v_cur_pos = posCS;
		gl_Position = posCS;	
	#else
		float w = calc_line_width(posCS.w, a_width, aspect);
		vec2 offset = calc_offset(dirCS.xy, aspect, w);

		posCS.xy += offset * a_side;
		gl_Position = posCS;
	#endif

	v_uv			= uv_motion(a_texcoord0);
    v_counters		= a_counters;

#ifdef ENABLE_POLYLINE_MASK
	MASK_UV = mask_uv(a_position);
#endif //ENABLE_POLYLINE_MASK
}
