$input a_position, a_texcoord0, a_texcoord1, a_texcoord2
$output v_color, v_texcoord0

#include <bgfx_shader.sh>
#include "polyline/polyline.sh"

#define a_linedir   a_texcoord2

void main() {
	float aspect = u_viewRect.z / u_viewRect.w;

	vec4 posCS = mul(u_modelViewProj, vec4(a_position, 1.0));
	vec4 dirCS = mul(u_modelViewProj, vec4(a_linedir, 0.0));

	float w = calc_line_width(posCS.w, a_width);
	vec2 offset = calc_offset(dirCS.xy, aspect, w);

	posCS.xy += offset * a_side;
	gl_Position = posCS;

    v_color			= u_color;
	v_uv			= a_texcoord0;
    v_counters		= a_counters;
}
