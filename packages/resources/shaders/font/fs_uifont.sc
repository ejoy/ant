$input v_color0, v_texcoord0
#include <bgfx_shader.sh>
#include "../../common/common.sh"

SAMPLER2D(s_tex, 0);

uniform vec4 u_mask;
#define u_color_mask	u_mask.x
#define u_color_range	u_mask.y

#define u_effect_mask	u_mask.z
#define u_effect_range	u_mask.w

#if defined(OUTLINE_EFFECT) || defined(GLOW_EFFECT) || defined(SHADOW_EFFECT)
uniform vec4 u_effect_color;
#endif

float sdf(float dis, float mask, float range){
	return smoothstep(mask - range, mask + range,  dis);
}

void main()
{
	float dis = texture2D(s_tex, v_texcoord0).a;
	vec4 color = v_color0;
	color.a = color.a * sdf(dis, u_color_mask, u_color_range);

#if defined(SHADOW_EFFECT)
	vec2 fonttexel = vec2_splat(1.0) / 2048.0;
	dis = texture2D(s_tex, v_texcoord0+fonttexel);
#endif

#if defined(OUTLINE_EFFECT) || defined(GLOW_EFFECT) || defined(SHADOW_EFFECT)
	vec4 effectcolor = u_effect_color;
	effectcolor.a = effectcolor.a * sdf(dis, u_effect_mask, u_effect_range);
	color += effectcolor;
#endif

	gl_FragColor = color;
}
