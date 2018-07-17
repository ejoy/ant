// terrain shader sample
$input v_position, v_texcoord0,v_normal ,v_texcoord1

#include "../common/common.sh"

// only Int1,Vec4,Mat3,Mat4 supported 
uniform vec4 s_lightIntensity;
uniform vec4 s_lightColor;
SAMPLER2D(s_baseTexture,0);
SAMPLER2D(s_maskTexture,1);
uniform int s_showMode;


void main()
{
	
	vec4  diffuseColor = vec4(1.0,1.0,1.0,1.0);
	//vec4  skyColor = vec4(0.5,0.7,0.7,1.0);
	vec4  skyColor = s_lightColor;
	vec4  groundColor = vec4(0.3,0.3,0.3,1.0);
	vec4  horzColor = vec4(0.25,0.25,0.25,1.0);
    vec3  lightDirection = vec3(0,60,30);
	lightDirection = normalize(lightDirection);
	
	float lightIntensity = saturate(dot(v_normal, lightDirection))*(1+s_lightIntensity[0]);
	if(lightIntensity<0.8)
	   lightIntensity=0.8;
    vec4  color = saturate(diffuseColor * lightIntensity);
	
	
	vec4 mask = vec4(v_position.y/20.0, v_position.y/20.0, v_position.y/20.0 , 1.0);
	vec4 textureColor = texture2D(s_baseTexture,v_texcoord0);
	vec4 maskColor 	  = vec4(1,1,1, texture2D(s_maskTexture,v_texcoord1).r);
	//if(maskColor.r<=0.2)
	//	discard;
	if( s_showMode == 1) {
		color = vec4(v_normal,1.0); //*mask;
		gl_FragColor = color;
		return ;
	}
	vec4 amColor = horzColor*0.1 * textureColor;
	//color = saturate(color*textureColor*maskColor);
	gl_FragColor = skyColor*textureColor*maskColor*lightIntensity;
	//gl_FragColor = diffuseColor;
}
