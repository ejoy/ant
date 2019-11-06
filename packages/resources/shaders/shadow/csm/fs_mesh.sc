$input v_positionWS, v_texcoord0, v_lightdirTS, v_viewdirTS, v_packed_info, 

#define v_normal_Y_angle	v_packed_info.x
#define v_distanceVS		v_packed_info.y
/*
 * Copyright 2013-2014 Dario Manesku. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include "common.sh"
#include "common/uniforms.sh"
#include "common/lighting.sh"

#include "common/shadow.sh"

#include "common/postprocess.sh"

SAMPLER2D(s_basecolor, 	0);
SAMPLER2D(s_normal, 	1);

uniform vec4 u_fog_color;
uniform vec4 u_specularColor;
uniform vec4 u_specularLight;

void main()
{
	vec4 ntexdata 	= texture2D(s_normal, v_texcoord0.xy);
	float gloss 	= ntexdata.z;
	vec3 normal 	= unproject_normal(remap_normal(ntexdata.xy));

	vec4 basecolor  = texture2D(s_basecolor, v_texcoord0.xy);
	vec4 lightcolor = directional_color[0] * directional_intensity[0].x;
	
	vec4 ambientcolor= calc_ambient_color(ambient_mode.x, v_normal_Y_angle) * basecolor;

	vec4 scenecolor	= saturate(ambientcolor + calc_lighting_BH(normal, v_lightdirTS, v_viewdirTS, lightcolor, 
															basecolor, u_specularColor, gloss, u_specularLight.x));

	vec4 fog_factor = calc_fog_factor(u_fog_color, 0.0035, 1.442695, v_distanceVS);
	float visibility = shadow_visibility(v_distanceVS, v_positionWS);
	
	vec4 finalcolor = vec4(mix(u_shadow_color.rgb, scenecolor.rgb, visibility), scenecolor.a);

	gl_FragData[0] = mix(u_fog_color, finalcolor, fog_factor);
#ifdef BLOOM_ENABLE
	gl_FragData[1] = bloom_color(scenecolor);
#endif
}
