//input attributes: a_texcoord1: [side, width, counters]
#define a_side		a_texcoord1.x
#define a_width		a_texcoord1.y
#define a_counters	a_texcoord1.z

//output varying:
#define v_uv		v_texcoord0.xy
#define v_counters	v_texcoord0.z

// uniforms:
uniform vec4            u_line_info;
#define u_line_width    u_line_info.x
#define u_visible       u_line_info.y

uniform vec4            u_color;

uniform vec4 u_tex_param;
#define u_repeat        u_tex_param.xy
#define u_tex_enable    u_tex_param.z

uniform vec4 u_dash_info;
#define u_dash_enable    u_dash_info.x
#define u_dash_round     u_dash_info.y
#define u_dash_ratio     u_dash_info.z


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