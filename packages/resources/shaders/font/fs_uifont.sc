$input v_color0, v_texcoord0
#include <bgfx_shader.sh>
#include "../../common/common.sh"

SAMPLER2D(s_tex, 0);

void main()
{
	float dis = texture2D(s_tex, v_texcoord0).a;
	dis = smoothstep(0.68 - 0.2, 0.68 + 0.2, dis);
	gl_FragColor.rgb	= v_color0.rgb;
	gl_FragColor.a		= dis;
}
