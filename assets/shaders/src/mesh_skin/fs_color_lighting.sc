$input v_normal, v_viewdir, v_color0
#include "common.sh"

SAMPLER2D(s_basecolor, 0);

uniform vec4 directional_lightdir[1];
uniform vec3 u_eyepos;

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

vec3 calc_directional_light(vec3 normal, vec3 lightdir, vec3 viewdir)
{
	float ndotl = dot(normal, lightdir);
	float diffuse = max(0.0, ndotl);

	//vec3 specular_color = vec3(1.0, 1.0, 1.0);
	float fres = fresnel(ndotl, 0.2, 5);	
	float specular = step(0, ndotl) * fres * specular_blinn(lightdir, normal, viewdir);

	return diffuse + specular;
}

void main()
{
	vec3 normal = normalize(v_normal);
	vec4 color = v_color0;
	vec3 viewdir = normalize(v_viewdir);

	//gl_FragColor.xyz = directional_lightdir[0].xyz;

	gl_FragColor.xyz = calc_directional_light(normal, directional_lightdir[0], viewdir) * color; 
	gl_FragColor.w = 1.0;
}