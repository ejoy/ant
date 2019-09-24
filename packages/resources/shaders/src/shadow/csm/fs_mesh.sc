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

SAMPLER2D(s_basecolor, 	0);
SAMPLER2D(s_normal, 	1);

uniform vec4 u_fog_color;
uniform vec4 u_specularColor;
uniform vec4 u_specularLight;

float has_negative_number(vec4 v)
{
	if (v.x < 0 || v.y < 0 || v.z < 0 || v.w < 0)
		return 0;
	return 1;
}

void main()
{
	int cascadeidx = select_cascade(v_distanceVS);
	mat4 m = u_csm_matrix[cascadeidx];
	vec4 shadowcoord = mul(m, v_positionWS);

	float visibility = hardShadow(s_shadowmap, shadowcoord, u_shadowmap_bias);

	//vec4 color_coverage = get_color_coverage(cascadeidx);
	
	vec4 ntexdata 	= texture2D(s_normal, v_texcoord0.xy);
	float gloss 	= ntexdata.z;
	vec3 normal 	= unproject_normal(ntexdata.xy);

	vec4 basecolor  = texture2D(s_basecolor, v_texcoord0.xy);
	vec4 lightcolor = directional_color[0] * directional_intensity[0].x;
	
	vec4 ambientcolor = calc_ambient_color(ambient_mode.x, v_normal_Y_angle) * basecolor;

	vec4 fog_factor= calc_fog(u_fog_color, 0.0035, 1.442695, v_distanceVS);
    
	vec4 scenecolor	= saturate(ambientcolor + calc_lighting_BH(normal, v_lightdirTS, v_viewdirTS, lightcolor, 
															basecolor, u_specularColor, gloss, u_specularLight.x));
	vec4 finalcolor = vec4(mix(u_shadow_color.rgb, scenecolor.rgb, visibility), scenecolor.a);

	gl_FragColor = mix(u_fog_color, finalcolor, fog_factor);
}
