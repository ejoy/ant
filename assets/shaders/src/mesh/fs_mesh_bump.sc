$input v_normal, v_tangent, v_bitangent, v_tex0, v_pos

#include "common.sh"
#include "common/lighting.sh"

SAMPLER2D(s_basecolor,  0);
SAMPLER2D(s_normal, 1);

uniform vec4 directional_lightdir[1];
uniform vec4 eyepos;

void main()
{
	mat3 tbn = mat3(normalize(v_tangent),
					normalize(v_bitangent),
					normalize(v_normal));
	tbn = transpose(tbn);

	vec3 normal = normalize(texture2D(s_normal, v_tex0) * 2.0 - 1.0);
	//normal.z = sqrt(1.0 - dot(normal.xy, normal.xy) );

	vec4 color = toLinear(texture2D(s_basecolor, v_tex0) );

	vec3 lightdir = mul(directional_lightdir[0], tbn);
	vec3 viewdir = mul(normalize(eyepos - v_pos), tbn);

	gl_FragColor.xyz = calc_directional_light(normal, lightdir, viewdir, 64) * color;
	gl_FragColor.w = 1.f;
}