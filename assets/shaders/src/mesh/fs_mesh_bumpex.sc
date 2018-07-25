$input v_normal, v_tangent, v_bitangent, v_tex0, v_pos

#include <common.sh>

#include "common/uniforms.sh"

SAMPLER2D(s_basecolor,  0);
SAMPLER2D(s_normal, 1);

uniform vec4 u_specularColor;
uniform vec4 u_specularLight;

vec4 calc_lighting_BH(vec3 normal, vec3 lightdir, vec3 viewdir, 
						vec4 lightColor, vec4 diffuseColor, vec4 specularColor, 
						float gloss)
{
	float ndotl = max(0, dot(normal, lightdir));
	
	float hdotn = max(0, dot(normalize(viewdir + lightdir), normal));
	float shininess = specularColor.w;
	float specularFactor = pow(hdotn, shininess * 64);// * u_specularLight.x;

	vec3 diffuse = diffuseColor * lightColor * ndotl;
	float ss = specularColor * specularFactor * gloss;

	vec3 specular = specularColor * specularFactor * gloss;
	vec3 ambient = diffuseColor * lightColor * 0.12;

	return vec4(diffuse + ambient + specular, 1.0);//vec4(diffuse + specular + ambient, 1.0);	
}

void main()
{
	mat3 tbn = transpose(
					mat3(normalize(v_tangent),
					normalize(v_bitangent),
					normalize(v_normal)));	

	vec4 ntexdata = texture2D(s_normal, v_tex0);	
	vec3 normal = vec3(ntexdata.xy, 0.0);
	normal.xy = normal.xy * 2.0 - 1.0;	
	normal.z = sqrt(1.0 - dot(normal.xy, normal.xy));

	//vec4 color = toLinear(texture2D(s_basecolor, v_tex0) );
	vec4 color = texture2D(s_basecolor, v_tex0);


	vec3 lightdir = mul(directional_lightdir[0], tbn);
	vec3 viewdir = mul(normalize(u_eyepos - v_pos), tbn);

	float gloss = ntexdata.z;
	vec4 lightcolor = directional_color[0] * directional_intensity[0].x;
	gl_FragColor = calc_lighting_BH(normal, lightdir, viewdir, lightcolor, color, u_specularColor, gloss);
}