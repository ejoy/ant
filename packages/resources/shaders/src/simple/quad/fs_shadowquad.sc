$input v_texcoord0

#include <bgfx_shader.sh>

#ifdef SM_LINEAR
SAMPLER2D(s_shadowmap, 0);
#else
SAMPLER2DSHADOW(s_shadowmap, 0);
#endif

void main()
{
	const float visable = shadow2D(s_shadowmap, vec4(v_texcoord0, 1.0, 1.0)).r;	
    gl_FragColor = vec4(visable, visable, visable, 1.0);
}