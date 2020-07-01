// terrain shader sample
$input v_normal, v_positionWS

#include "common.sh"
#include "common/uniforms.sh"
#include "common/lighting.sh"

#define v_distanceVS v_positionWS.w

void main()
{
	// only diffuse?
	float ntol 			= max(0, dot(v_normal.xyz, u_directional_lightdir.xyz));
	float lightIntensity= ntol * u_directional_intensity.x;
	vec4 finalcolor 	= saturate(vec4(u_directional_color.rgb * lightIntensity, 1.0));
    gl_FragColor        = finalcolor;
}