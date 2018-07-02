$input v_normal, v_tex0, v_pos
#include "common.sh"

SAMPLER2D(s_basecolor, 0);

uniform vec4 directional_lightdir[1];
uniform vec3 eyepos;

float fresnel(float _ndotl, float _bias, float _pow)
{
	float facing = (1.0 - _ndotl);
	return max(mix(pow(facing, _pow), 1, _bias), 0.0);
}

float specular_blinn(vec3 lightdir, vec3 normal, vec3 viewdir)
{
	vec3 half = normalize(lightdir + viewdir);

	float hdotn = dot(half, normal);	// Phong need check dot result, but Blinn-Phong not
	float shiness = 8.0;
	return pow(hdotn, shiness);
}

vec3 calc_directional_light(vec3 normal, vec3 pos)
{
	float ndotl = dot(normal, directional_lightdir[0]);
	float diffuse = max(0.0, ndotl);

	vec3 viewdir = normalize(eyepos - pos);
	
	//vec3 specular_color = vec3(1.0, 1.0, 1.0);
	float fres = fresnel(ndotl, 0.2, 5);	
	float specular = step(0, ndotl) * fres * specular_blinn(directional_lightdir[0], normal, viewdir);

	return specular;
}

void main()
{
	vec3 normal = normalize(v_normal);
	vec4 color = toLinear(texture2D(s_basecolor, v_tex0));

	gl_FragColor.xyz = calc_directional_light(normal, v_pos) * color; 
	gl_FragColor.w = 1.0;
}