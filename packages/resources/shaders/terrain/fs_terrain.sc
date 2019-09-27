// terrain shader sample
$input v_normal, v_texcoord0, v_texcoord1, v_positionWS

#include "common.sh"
#include "common/uniforms.sh"
#include "common/lighting.sh"
#include "common/shadow.sh"

#define v_distanceVS v_positionWS.w

SAMPLER2D(s_baseTexture, 0);
SAMPLER2D(s_maskTexture, 1);

void main()
{
	// only diffuse?
	float ntol 			= max(0, dot(v_normal.xyz, directional_lightdir[0].xyz));
	float lightIntensity= ntol * directional_intensity[0].x;
    vec4 lightColor 	= vec4(directional_color[0].xyz * lightIntensity, 1.0);

	vec4 textureColor 	= vec4(texture2D(s_baseTexture, v_texcoord0).rgb, 1.4);
	vec4 maskColor    	= vec4(1.0, 1.0, 1.0, texture2D(s_maskTexture,v_texcoord1).r);
	//vec4 mask 			= vec4(v_position.y/20.0, v_position.y/20.0, v_position.y/20.0 , 1.0);

	vec4  ambientColor = vec4(calc_ambient_color(ambient_mode.x, v_normal.y).rgb, 0.0) * textureColor;
	vec4  diffuseColor = lightColor * textureColor * maskColor;
	
	float visilible 	= shadow_visibility(v_distanceVS, v_positionWS);
	vec4 finalcolor 	= saturate(ambientColor + diffuseColor);
	gl_FragColor.rgb 	= mix(u_shadow_color, finalcolor, visilible);
	gl_FragColor.a 		= finalcolor.a;
}