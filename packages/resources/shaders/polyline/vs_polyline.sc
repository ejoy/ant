$input a_position, a_texcoord0, a_texcoord1, a_texcoord2, a_texcoord3
$output v_color, v_texcoord0

#include <bgfx_shader.sh>
#include "polyline/polyline.sh"

#define a_prevpos	a_texcoord2
#define a_nextpos	a_texcoord3

bool is_2d_point_equal(vec2 p0, vec2 p1){
	return p0.x == p1.x && p0.y == p1.y;
}
	
void main() {
	float aspect = u_viewRect.z / u_viewRect.w;

	vec4 posCS		= mul(u_modelViewProj, vec4(a_position, 1.0));
	vec4 prevPosCS	= mul(u_modelViewProj, vec4(a_prevpos, 1.0));
	vec4 nextPosCS	= mul(u_modelViewProj, vec4(a_nextpos, 1.0));

	vec2 currentP_2D= fix(posCS,	aspect);
	vec2 prevP_2D	= fix(prevPosCS,aspect);
	vec2 nextP_2D	= fix(nextPosCS,aspect);

	float w = calc_line_width(posCS.w, a_width);

	vec2 dir1 = currentP_2D - prevP_2D;
	vec2 dir2 = nextP_2D - currentP_2D;
	vec2 dirCS= normalize(dir1 + dir2);

	vec2 offset = calc_offset(dirCS.xy, aspect, w);
	posCS.xy += offset * a_side;

	gl_Position = posCS;

	v_color		= u_color;
	v_uv		= a_texcoord0;
	v_counters	= a_counters;
}
