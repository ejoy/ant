$input v_color0, v_texcoord0
#include <bgfx_shader.sh>
#include "../../common/common.sh"

SAMPLER2D(s_tex, 0);

void main()
{
	float distance = texture2D(s_tex, v_texcoord0).a;
	distance = smoothstep(0.7 - 0.1, 0.7 + 0.1, distance);
	vec4 color = v_color0 * distance;
	
//	color.x = color.x+1;
//	color.y = color.y+1;
//	color.z = color.z+1;
//	color.w = color.w+1;
	gl_FragColor = color;
}
