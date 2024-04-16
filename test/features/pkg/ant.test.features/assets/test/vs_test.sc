$input a_position a_tangent a_texcoord0
$output v_bitangent v_normal v_posWS v_tangent v_texcoord0

struct VSInput {
	vec3 position;
	vec4 tangent;
	vec2 texcoord0;
};

struct Varyings {
	vec3 bitangent;
	vec3 normal;
	vec3 posWS;
	vec3 tangent;
	vec2 texcoord0;
};

#include <bgfx_shader.sh>
#include <shaderlib.sh>

uniform vec4 u_emissive_factor;
uniform vec4 u_basecolor_factor;
uniform vec4 u_pbr_factor;


#include "common/transform.sh"
#include "common/common.sh"

//code gen by genshader.lua
vec4 CUSTOM_VS_POSITION(VSInput vsinput, inout Varyings varyings, out mat4 worldmat){
	worldmat = u_model[0];
	vec4 posCS;
	varyings.posWS = transform_worldpos(worldmat, vsinput.position, posCS);
	return posCS;
}
//code gen by genshader.lua
void CUSTOM_VS(mat4 worldmat, VSInput vsinput, inout Varyings varyings) {
	varyings.texcoord0 = vsinput.texcoord0;
	mat3 wm3 = (mat3)worldmat;
	const vec4 quat        = vsinput.tangent;
	const vec3 normal      = quat_to_normal(quat);
	const vec3 tangent     = quat_to_tangent(quat);
	varyings.normal        = mul(wm3, normal);
	varyings.tangent       = mul(wm3, tangent);
	varyings.bitangent     = cross(varyings.normal, varyings.tangent) * sign(quat.w);
}

void main()
{
    VSInput vsinput = (VSInput)0;
    Varyings varyings = (Varyings)0;

	vsinput.position = a_position;
	vsinput.tangent = a_tangent;
	vsinput.texcoord0 = a_texcoord0;

    mat4 worldmat = (mat4)0;
    gl_Position = CUSTOM_VS_POSITION(vsinput, varyings, worldmat);
#ifndef POSITION_ONLY
    CUSTOM_VS(worldmat, vsinput, varyings);
#endif //POSITION_ONLY

	v_bitangent = varyings.bitangent;
	v_normal = varyings.normal;
	v_posWS = varyings.posWS;
	v_tangent = varyings.tangent;
	v_texcoord0 = varyings.texcoord0;
}