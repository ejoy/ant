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
