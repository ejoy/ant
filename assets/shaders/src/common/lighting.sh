float fresnel(float _ndotl, float _bias, float _pow)
{
	float facing = (1.0 - _ndotl);
	return max(mix(pow(facing, _pow), 1, _bias), 0.0);
}

float specular_blinn(vec3 lightdir, vec3 normal, vec3 viewdir, float shininess)
{
	vec3 halfdir = normalize(lightdir + viewdir);

	float hdotn = dot(halfdir, normal);	// Phong need check dot result, but Blinn-Phong not	
	return pow(hdotn, shininess * 128);
}

vec3 calc_directional_light(vec3 normal, vec3 lightdir, vec3 viewdir, float shininess)
{
	float ndotl = dot(normal, lightdir);
	float diffuse = max(0.0, ndotl);
	//vec3 specular_color = vec3(1.0, 1.0, 1.0);
	float fres = fresnel(ndotl, 0.2, 5);	
	float specular = step(0, ndotl) * fres * specular_blinn(lightdir, normal, viewdir, shininess);

	return vec3(diffuse + specular);
}