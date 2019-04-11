$input v_texcoord0

#include <bgfx_shader.sh>
#include "common/uniforms.sh"

void main()
{
	const float visable = shadow2D(s_shadowmap0, vec4(v_texcoord0, 1.0, 1.0)).r;	
    gl_FragColor = vec4(visable, visable, visable, 1.0);
}