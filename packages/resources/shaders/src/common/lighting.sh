float fresnel(float _ndotl, float _bias, float _pow)
{
	float facing = (1.0 - _ndotl);
	return max(mix(pow(facing, _pow), 1, _bias), 0.0);
}

float specular_blinn(vec3 lightdir, vec3 normal, vec3 viewdir, float shininess)
{
	vec3 halfdir = normalize(lightdir + viewdir);

	float hdotn = max(0.0, dot(halfdir, normal));	// Phong need check dot result, but Blinn-Phong not	
	return pow(hdotn, shininess * 128.0);
}

vec3 calc_directional_light(vec3 normal, vec3 lightdir, vec3 viewdir, float shininess)
{
	float ndotl = dot(normal, lightdir);
	float diffuse = max(0.0, ndotl);
	//vec3 specular_color = vec3(1.0, 1.0, 1.0);
	float fres = fresnel(ndotl, 0.2, 5.0);	
	float specular = step(0, ndotl) * fres * specular_blinn(lightdir, normal, viewdir, shininess);

	float result = diffuse + specular;
	return vec3(result, result, result);
}

vec4 calc_ambient_color(float ambientMode,vec3 normalWS) 
{
	// gradient mode 
	if(ambientMode == 2.0) {
		float angle = normalWS.y;
		if(angle>0.0)
			return (ambient_skycolor*angle) + (ambient_midcolor*(1.0-angle));
		else {
			angle = - angle;
		    return (ambient_groundcolor*angle) + (ambient_midcolor*(1.0-angle));
		}	    
	}
	// default classic mode 
	return ambient_skycolor;
}

vec4 calc_lighting_BH(vec3 normal, vec3 lightdir, vec3 viewdir, 
						vec4 lightColor, vec4 diffuseColor, vec4 specularColor, 
						float gloss, float specularIntensity)
{
	float ndotl = max(0, dot(normal, lightdir));

	float hdotn = saturate(dot(normal,normalize(viewdir + lightdir)));
	float shininess = specularColor.w;   									 // spec shape
	float specularFactor = pow(hdotn, shininess * 128.0) * specularIntensity;  // spec intensity 

	vec3 diffuse = diffuseColor.xyz * lightColor.xyz * ndotl;
	vec3 specular = specularColor.rgb * specularFactor * gloss;              // gloss from normalmap texture 

	//return vec4(specularFactor * gloss, specularFactor * gloss, specularFactor * gloss, 1.0);
	//return vec4(specular,1.0);
	return vec4(diffuse + specular, 1.0);
}
