#ifndef __SHADER_LIGHTING_SH__
#define __SHADER_LIGHTING_SH__

// lighting
// uniform vec4 u_directional_lightdir;
// uniform vec4 u_directional_color;

// uniform vec4 u_light_color[MAX_LIGHT];	
// uniform vec4 u_light_pos[MAX_LIGHT];	//xyz: pos, w: light type
// uniform vec4 u_light_dir[MAX_LIGHT];	//point light: (0, 0, 0, 0), spot light, xyz: light dir, w: cutoff
// uniform vec4 u_light_param[MAX_LIGHT];	//xyz for attenuation: const, linear, quadratic, w: outcutoff

//TODO: if we need more accurate attenuation, we can utilize pos.w/dir.w/color.w to transfer data, right now, the light attenuation: light_color/(distance*distance), 
struct Light{
	vec4	pos;
	vec4	dir;
	vec4	color;
	float	type;
	float	intensity;
	float	inner_cutoff;
	float	outter_cutoff;
};

#if BGFX_SHADER_LANGUAGE_HLSL
StructuredBuffer<Light>	b_lights : register(t[9]);
#else	//!BGFX_SHADER_LANGUAGE_HLSL
BUFFER_RO(b_lights, LIGHT, 9);
#endif //BGFX_SHADER_LANGUAGE_HLSL

uniform vec4 u_eyepos;

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

// vec4 calc_point_lighting(vec3 normal, vec3 lightpos, vec3 viewdir, vec4 diffuse, vec4 specular, float shininess)
// {
//     // ambient
//     vec3 ambient = light.ambient * texture(material.diffuse, TexCoords).rgb;
  	
//     // diffuse 
//     vec3 norm = normalize(normal);
//     vec3 lightDir = normalize(light.position - FragPos);
//     float diff = max(dot(norm, lightDir), 0.0);
//     vec3 diffuse = light.diffuse * diff * texture(material.diffuse, TexCoords).rgb;  
    
//     // specular
//     vec3 viewDir = normalize(viewPos - FragPos);
//     vec3 reflectDir = reflect(-lightDir, norm);  
//     float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
//     vec3 specular = light.specular * spec * texture(material.specular, TexCoords).rgb;  
    
//     // attenuation
//     float distance    = length(light.position - FragPos);
//     float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));    

//     ambient  *= attenuation;  
//     diffuse   *= attenuation;
//     specular *= attenuation;   
        
//     vec3 result = ambient + diffuse + specular;
//     FragColor = vec4(result, 1.0);
// }

vec4 calc_fog_factor(vec4 color, float density, float LOG2, float distanceVS)
{
	return saturate(1.0/exp2(density*density*distanceVS*distanceVS*LOG2)) * color;
}

vec3 unproject_normal(vec3 normal)
{
	// projection back
	float pX = normal.x/(1.0 + normal.z);
	float pY = normal.y/(1.0 + normal.z);
	float denom = 2.0/(1.0 +pX*pX + pY*pY);
	normal.x = pX * denom;
	normal.y = pX * denom;
	normal.z = denom -1.0; 

	return normal;
}

vec3 remap_normal(vec2 normalTS)
{
	vec3 normal = vec3(normalTS, 0.0);
	normal.xy = normal.xy * 2.0 - 1.0;
	normal.z = sqrt((1.0 - dot(normal.xy, normal.xy)));
	return normal;
}

#endif //__SHADER_LIGHTING_SH__