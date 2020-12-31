$input v_color0, v_texcoord0
#include <bgfx_shader.sh>
#include "../../common/common.sh"

SAMPLER2D(s_tex, 0);

uniform vec4 u_mask;
#define u_edge_mask			u_mask.x
#define u_dist_multiplier	u_mask.y
#define u_outline_width		u_mask.z

#if defined(OUTLINE_EFFECT) || defined(GLOW_EFFECT) || defined(SHADOW_EFFECT)
uniform vec4 u_effect_color;
#endif //OUTLINE_EFFECT || GLOW_EFFECT || SHADOW_EFFECT

#if defined(SHADOW_EFFECT)
uniform vec4 u_shadow_offset;
#endif //SHADOW_EFFECT

float smoothing_result(float dis, float mask, float range){
	return smoothstep(mask - range, mask + range,  dis);
}

void main()
{
	float dis = texture2D(s_tex, v_texcoord0).a;
	vec4 color = v_color0;
	float magicnum = 128.0;
	float smoothing = length(fwidth(v_texcoord0)) * magicnum * u_dist_multiplier;
	float coloralpha = smoothing_result(dis, u_edge_mask, smoothing);

#if defined(OUTLINE_EFFECT)
	float outline_width	= smoothing * u_outline_width;
	float outline_mask	= u_edge_mask - outline_width;
	float alpha = smoothing_result(dis, outline_mask, smoothing);
	color		= vec4(lerp(u_effect_color.rgb, v_color0.rgb, coloralpha), alpha * v_color0.a);
#elif defined(SHADOW_EFFECT)
	float offsetdis = texture2D(s_tex, v_texcoord0+u_shadow_offset.xy).a;
	float shadow_mask = u_edge_mask - (offsetdis - dis)*smoothing;
	float alpha = smoothing_result(offsetdis, shadow_mask, smoothing);
	color		= vec4(lerp(u_effect_color.rgb, v_color0.rgb, coloralpha), alpha * v_color0.a);
#elif defined(GLOW_EFFECT)
	// vec4 effectcolor = u_effect_color;
	// effectcolor.a = sdf(dis, u_effect_mask, u_effect_range);
	// color = lerp(effectcolor, color, color.a);
#else
	color.a = coloralpha;
#endif

	gl_FragColor = color;
}
