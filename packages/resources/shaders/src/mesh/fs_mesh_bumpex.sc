$input v_texcoord0, v_lightdir, v_viewdir, v_normal

#include <common.sh>

#include "common/uniforms.sh"
#include "common/lighting.sh"

#include "shadow/csm/shadow_common.sh"

SAMPLER2D(s_basecolor,  0);
SAMPLER2D(s_normal, 	1);

uniform vec4 u_specularColor;
uniform vec4 u_specularLight;

void main()
{
	vec4 ntexdata 	= texture2D(s_normal, v_texcoord0.xy);
	float gloss 	= ntexdata.z;
	vec3 normal 	= unproject_noraml(ntexdata.xy);

	vec4 basecolor  = texture2D(s_basecolor, v_texcoord0.xy);
	vec4 lightcolor = directional_color[0] * directional_intensity[0].x;
	
	vec4 ambientcolor = calc_ambient_color(ambient_mode.x, v_normal.y) * basecolor;
    
	gl_FragColor 	= saturate(ambientcolor + calc_lighting_BH(normal, v_lightdir, v_viewdir, lightcolor, 
															basecolor, u_specularColor, gloss, u_specularLight.x));
}