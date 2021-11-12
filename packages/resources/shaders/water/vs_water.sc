$input a_position
$output v_texcoord0 v_posWS v_normal v_tangent v_bitangent

#include <bgfx_shader.sh>
#include "common/common.sh"
#include "common/constants.sh"
#include "water.sh"

uniform vec4	u_wave_a = vec4(1.0, 1.0, 0.35, 3.0); 	// xy = Direction, z = Steepness, w = Length
uniform	vec4	u_wave_b = vec4(1.0, 0.6, 0.30, 1.55);	// xy = Direction, z = Steepness, w = Length
uniform	vec4	u_wave_c = vec4(1.0, 1.3, 0.25, 0.9); 	// xy = Direction, z = Steepness, w = Length

// Wave function:
vec4 wave(vec4 parameter, vec2 position, float time, inout vec3 tangent, inout vec3 binormal)
{
	float	wave_steepness	 = parameter.z;
	float	wave_length		 = parameter.w;

	float k  = PI2 / wave_length;
	float c  = sqrt(9.8 / k);
	vec2  d  = normalize(parameter.xy);
	float f  = k * (dot(d, position) - c * time);
	float a  = wave_steepness / k;
	
	tangent	+= normalize(vec3(1.0-d.x * d.x * (wave_steepness * sin(f)), d.x * (wave_steepness * cos(f)), -d.x * d.y * (wave_steepness * sin(f))));
	binormal+= normalize(vec3(-d.x * d.y * (wave_steepness * sin(f)), d.y * (wave_steepness * cos(f)), 1.0-d.y * d.y * (wave_steepness * sin(f))));

	return vec4(d.x * (a * cos(f)), a * sin(f) * 0.25, d.y * (a * cos(f)), 0.0);
}

void main()
{
	float time   = u_current_time * u_wave_speed;
	vec4 vertex  = vec4(a_position, 1.0);
	vec4 vertexWS= mul(u_model[0], vertex);
    vec3 tangent = vec3_splat(0.0);
    vec3 bitangent = vec3_splat(0.0);

    vertex += wave(u_wave_a, vertexWS.xz, time, tangent, bitangent);
    vertex += wave(u_wave_b, vertexWS.xz, time, tangent, bitangent);
    vertex += wave(u_wave_c, vertexWS.xz, time, tangent, bitangent);

	v_tangent = normalize(tangent);
	v_bitangent = normalize(bitangent);

	vec4 vertexVS= mul(u_view, vertexWS);
    gl_Position  = mul(u_proj, vertexVS);
    v_normal     = normalize(cross(tangent, bitangent));
	
    v_posWS      = vec4(vertexWS.xyz, vertexVS.z);
    v_texcoord0  = vec3(vertexWS.xz * u_uv_scale, gl_Position.z);
}
