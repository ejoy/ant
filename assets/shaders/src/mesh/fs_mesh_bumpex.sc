$input v_tex0, v_lightdir, v_viewdir

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

	vec3 specular = specularColor.rbg * specularFactor * gloss;
	vec3 ambient = (diffuseColor * lightColor * 0.12).rgb;

	//return vec4(specularFactor * gloss, specularFactor * gloss, specularFactor * gloss, 1.0);
	return vec4(diffuse + ambient + specular, 1.0);
}

void main()
{
	vec2 tt = vec2(v_tex0.x, 1-v_tex0.y);

	vec4 ntexdata = texture2D(s_normal, tt);	
	vec3 normal = vec3(ntexdata.xy, 0.0);
	normal.xy = normal.xy * 2.0 - 1.0;
	normal.z = sqrt(1.0 - dot(normal.xy, normal.xy));

	vec4 basecolor = toLinear(texture2D(s_basecolor, tt));
	//vec4 basecolor = texture2D(s_basecolor, tt);

	// vec3 lightdir = mul(directional_lightdir[0], tbn);
	// vec3 viewdir = mul(normalize(u_eyepos - v_pos), tbn);

	float gloss = ntexdata.z;
	vec4 lightcolor = directional_color[0] * directional_intensity[0].x;
	gl_FragColor = calc_lighting_BH(normal, v_lightdir, v_viewdir, lightcolor, basecolor, u_specularColor, gloss);
}