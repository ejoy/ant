$input a_position, a_texcoord0, a_texcoord1, a_texcoord2, a_texcoord3
$output v_texcoord0

#include <bgfx_shader.sh>
#include "polyline/polyline.sh"
#include "common/uvmotion.sh"

#define a_prevpos	a_texcoord2
#define a_nextpos	a_texcoord3

int is_vec2_equal(vec2 lhs, vec2 rhs)
{
	return lhs.x == rhs.x && lhs.y == rhs.y;
}

vec4 calc_line_vertex_in_screen_space(vec3 pos, vec3 prev_pos, vec3 next_pos, float segmentwidth, float side)
{
	float aspect = u_viewRect.z / u_viewRect.w;

	vec4 posCS		= mul(u_modelViewProj, vec4(pos, 1.0));
	vec4 prevPosCS	= mul(u_modelViewProj, vec4(prev_pos, 1.0));
	vec4 nextPosCS	= mul(u_modelViewProj, vec4(next_pos, 1.0));

	vec2 currentP_2D= fix(posCS,	aspect);
	vec2 prevP_2D	= fix(prevPosCS,aspect);
	vec2 nextP_2D	= fix(nextPosCS,aspect);

	float w = calc_line_width(posCS.w, segmentwidth);

	vec2 dirCS;
	if (is_vec2_equal(currentP_2D, prevP_2D)){
		dirCS = normalize(nextP_2D-currentP_2D);
	} else if (is_vec2_equal(currentP_2D, nextP_2D)) {
		dirCS = normalize(currentP_2D-prevP_2D);
	} else {
		vec2 dir1 = normalize(currentP_2D-prevP_2D);
		vec2 dir2 = normalize(nextP_2D-currentP_2D);
		dirCS = normalize(dir1+dir2);
		float cosv = max(10e-6, dot(dir1, dirCS));
		w /= cosv;
	}

	vec2 offset = calc_offset(dirCS.xy, aspect, w);
	posCS.xy += offset * side;
	return posCS;
}

void main() {
	gl_Position = calc_line_vertex_in_screen_space(a_position, a_prevpos, a_nextpos, a_width, a_side);

    v_uv		= uv_motion(a_texcoord0);
	v_counters	= a_counters;
}
