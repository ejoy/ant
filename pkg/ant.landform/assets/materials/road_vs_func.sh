#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
#include "default/inputs_structure.sh"

static const vec2 s_rotate_texcoords[] = {
	vec2(0, 1),
	vec2(0, 0),
	vec2(1, 0),
	vec2(1, 1),
};

vec2 get_tex(uint idx){
	return s_rotate_texcoords[idx];
}

vec2 get_rotated_texcoord(float r, vec2 tex){
	uint xmask = uint(tex.x);
	uint ymask = uint(tex.y);
	uint idx = xmask|(ymask<<1);

	uint indices[] = {1, 2, 0, 3};
	return get_tex((r / 90 + indices[idx]) % 4);
}

void CUSTOM_VS_FUNC(in VSInput vs_input, inout VSOutput vs_output)
{
    float road_texcoord_r = vs_input.idata1.x;
	float road_state      = vs_input.idata1.y;

	highp vec4 posWS = vec4(vs_input.pos + vs_input.idata0.xyz, 1.0);
	vs_output.clip_pos = transform2clipspace(posWS);

	vs_output.uv0	    = get_rotated_texcoord(road_texcoord_r, vs_input.uv0).xy;
	vs_output.user0		= vec4(road_state, 0, 0, 0);
	vs_output.normal	= vec3(0.0, 1.0, 0.0);
	vs_output.tangent	= vec3(1.0, 0.0, 0.0);
	vs_output.world_pos = posWS;
	vs_output.world_pos.w = mul(u_view, vs_output.world_pos).z;
}