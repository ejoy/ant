$input v_texcoord0, v_normal, v_viewdir

#include "common.sh"
SAMPLER2D(s_basecolor, 0);

uniform vec4 u_lightdir;

vec2 specular_blinn(vec3 _lightDir, vec3 _normal, vec3 _viewDir)
{
	float ndotl = dot(_normal, _lightDir);
	vec3 reflected = _lightDir - 2.0*ndotl*_normal; // reflect(_lightDir, _normal);
	float rdotv = dot(reflected, _viewDir);
	return vec2(ndotl, rdotv);
}

float fresnel(float _ndotl, float _bias, float _pow)
{
	float facing = (1.0 - _ndotl);
	return max(_bias + (1.0 - _bias) * pow(facing, _pow), 0.0);
}

vec3 calc_directional_light(vec3 normal, vec3 lightdir, vec3 viewdir)
{
	float ndotl = dot(normal, lightdir);
	float diffuse = max(0.0, ndotl);
	//vec3 specular_color = vec3(1.0, 1.0, 1.0);
	float fres = fresnel(ndotl, 0.2, 5.0);	
	float specular = step(0, ndotl) * fres * specular_blinn(lightdir, normal, viewdir);

	return vec3_splat(diffuse + specular);
}

void main()
{
	vec4 color = toLinear(texture2D(s_basecolor, v_texcoord0));
	gl_FragColor.xyz = calc_directional_light(v_normal, u_lightdir.xyz, v_viewdir) * color.xyz;	
	gl_FragColor.w = 1.f;	
}