$input v_color0, v_texcoord0
#include <bgfx_shader.sh>
#include "../../common/common.sh"

SAMPLER2D(s_texFont, 0);

void main()
{
	float distance = texture2D(s_texFont, v_texcoord0).a;
	distance = smoothstep(0.7 - 0.1, 0.7 + 0.1, distance);
	vec4 color = v_color0 * distance;

	gl_FragColor = color;
}
