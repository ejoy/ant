$input a_position, a_normal, a_tex0,a_tangent
$output v_tex0, v_lightdir, v_viewdir,v_normal,v_tangent,v_bitangent


#include "common/uniforms.sh"

#include <bgfx_shader.sh>

void main()
{
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
	vec4 worldpos = mul(u_model[0], vec4(pos, 1.0));

	v_tex0 = a_tex0;

	vec3 normal = normalize(mul(u_model[0], a_normal.xyz));
	vec3 tangent = normalize(mul(u_model[0], a_tangent.xyz));
	vec3 bitangent = (cross(normal,tangent))* a_tangent.w;
	//bitangent = -bitangent;

	v_normal = normal;
	v_tangent = tangent;
	v_bitangent = bitangent;

 	mat3 tbn = transpose	(
			mat3((tangent),
			normalize(bitangent),
			(normal)));


	v_lightdir 	= mul(directional_lightdir[0].xyz , tbn);
	v_viewdir 	= mul(normalize( u_eyepos - worldpos).xyz, tbn);	
	v_normal    = normal;
}