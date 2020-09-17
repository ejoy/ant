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
	float aspect 			= u_viewRect.z / u_viewRect.w;
	float pixelWidthRatio	= 1. / (u_viewRect.z * u_proj[0][0]);

	vec4 finalPosition = mul(u_modelViewProj, vec4(a_position, 1.0));
	vec4 prevPos	= mul(u_modelViewProj, vec4(a_prevpos, 1.0));
	vec4 nextPos	= mul(u_modelViewProj, vec4(a_nextpos, 1.0));

	vec2 currentP	= fix(finalPosition, aspect);
	vec2 prevP		= fix(prevPos, aspect);
	vec2 nextP		= fix(nextPos, aspect);
	
	float pixelWidth = finalPosition.w * pixelWidthRatio;
	float w = 1.8 * pixelWidth * u_line_width * a_width;

	vec2 dir;
	if(is_2d_point_equal(nextP, currentP))
		dir = normalize(currentP - prevP);
	else if(is_2d_point_equal(prevP, currentP))
		dir = normalize(nextP - currentP);
	else {
		vec2 dir1 = normalize(currentP - prevP);
		vec2 dir2 = normalize(nextP - currentP);
		dir = normalize(dir1 + dir2);
	}

	vec2 offset = calc_offset(dir.xy, aspect, w);
	finalPosition.xy += offset * a_side;

	gl_Position = finalPosition;

	v_color			= u_color;
	v_uv			= a_texcoord0;
	v_counters		= a_counters;
}
