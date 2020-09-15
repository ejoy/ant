$input a_position, a_texcoord0, a_texcoord1, a_texcoord2
$output v_color, v_texcoord0

#include <bgfx_shader.sh>
#include "polyline/polyline.sh"

#define v_uv		v_texcoord0.xy
#define v_counters	v_texcoord0.z

#define a_linedir   a_texcoord2

vec2 fix( vec4 i, float aspect ) {
	vec2 res = i.xy / i.w;
	res.x *= aspect;
	return res;
}

vec2 calc_offset(vec2 dir, float aspect, float w)
{
	vec2 normal = normalize(vec2(-dir.y, dir.x));
	normal.x /= aspect;
	normal *= 0.5 * w;

    return normal;
}

void main() {
	float aspect 			= u_viewRect.z / u_viewRect.w;
	float pixelWidthRatio	= 1. / (u_viewRect.z * u_proj[0][0]);

	vec4 finalPosition      = mul(u_modelViewProj, vec4(a_position, 1.0));
	vec4 dir                = mul(u_modelViewProj, vec4(a_linedir, 0.0));

	float pixelWidth        = finalPosition.w * pixelWidthRatio;
	float w                 = 1.8 * pixelWidth * u_line_width * a_width;

	vec2 offset = calc_offset(dir.xy, aspect, w);

	finalPosition.xy += offset * a_side;
	gl_Position = finalPosition;

    v_color			= u_color;
	v_uv			= a_texcoord0;
    v_counters		= a_counters;
}
