// terrain shader sample
$input v_normal, v_positionWS

#include "common.sh"
#include "common/uniforms.sh"
#include "common/lighting.sh"

#define v_distanceVS v_positionWS.w

void main()
{
	// only diffuse?
	float ntol 			= max(0, dot(v_normal.xyz, directional_lightdir[0].xyz));
	float lightIntensity= ntol * directional_intensity[0].x;
    vec4 lightColor 	= vec4(directional_color[0].xyz * lightIntensity, 1.0);

	vec4  ambientColor  = vec4(calc_ambient_color(ambient_mode.x, v_normal.y).rgb, 0.0);
	vec4  diffuseColor  = lightColor; 
	
	vec4 finalcolor 	= saturate(ambientColor + diffuseColor);
    gl_FragColor        = finalcolor;
}