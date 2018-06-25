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
	float hdotn = dot(half, normal);

	float shiness = 128.0;
	return pow(hdotn, shiness);
}

void main()
{
	vec3 normal = normalize(v_normal);

	vec4 color = toLinear(texture2D(s_basecolor, v_tex0));

	float ndotl = dot(normal, directional_lightdir[0]);	
	vec3 diffuse = color.xyz * max(0.0, ndotl);

	vec3 viewdir = normalize(eyepos - v_pos);
	
	//vec3 specular_color = vec3(1.0, 1.0, 1.0);
	float fres = fresnel(ndotl, 0.2, 5);	
	float specular = step(0, ndotl) * fres * specular_blinn(directional_lightdir[0], normal, viewdir);
	gl_FragColor.xyz = diffuse + specular;
	gl_FragColor.w = 1.0;
}