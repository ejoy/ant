#include "polyline/input.sh"

$input a_position a_texcoord0 a_texcoord1 a_texcoord2 a_texcoord3
$output v_texcoord0 MASK_UV

#include <bgfx_shader.sh>
#include "polyline/polyline.sh"
#include "common/uvmotion.sh"

#ifdef ENABLE_POLYLINE_MASK
#include "polyline/mask.sh"
#endif //ENABLE_POLYLINE_MASK

#define a_prevpos	a_texcoord2
#define a_nextpos	a_texcoord3

int is_vec2_equal(vec2 lhs, vec2 rhs)
{
	return lhs.x == rhs.x && lhs.y == rhs.y;
}

int is_vec3_equal(vec3 lhs, vec3 rhs)
{
	return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z;
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

	float w = calc_line_width(posCS.w, segmentwidth, aspect) * 0.5;

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

vec4 calc_line_vertex_in_world_space(vec3 pos, vec3 prev_pos, vec3 next_pos, float segmentwidth, float side)
{
	float w = segmentwidth * u_line_width * 0.5;
	vec3 normal = vec3(0.0, 1.0, 0.0);
	vec3 dir;
	if (is_vec3_equal(pos, prev_pos)){
		dir = normalize(next_pos - pos);
	} else if (is_vec3_equal(next_pos, pos)){
		dir = normalize(pos - prev_pos);
	} else {
		vec3 dir1 = normalize(pos - prev_pos);
		vec3 dir2 = normalize(next_pos - pos);
		dir = normalize(dir1+dir2);
		float cosv = max(10e-6, dot(dir1, dir));
		w /= cosv;
	}
	vec3 extent_dir = normalize(cross(dir, normal));
	pos += extent_dir * w * side;

	return mul(u_modelViewProj, vec4(pos, 1.0));
}

#ifdef USE_WORLD_SPACE
#define calc_line_vertex calc_line_vertex_in_world_space
#else //!USE_WORLD_SPACE
#define calc_line_vertex calc_line_vertex_in_screen_space
#endif //USE_WORLD_SPACE

void main()
{
	gl_Position = calc_line_vertex(a_position, a_prevpos, a_nextpos, a_width, a_side);

    v_uv		= a_texcoord0;//uv_motion(a_texcoord0);
	v_counters	= a_counters;

#ifdef ENABLE_POLYLINE_MASK
	MASK_UV = mask_uv(a_position);
#endif //ENABLE_POLYLINE_MASK
}
