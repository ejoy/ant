$input v_texcoord0

#include <bgfx_shader.sh>

uniform vec4 u_alphacutoff;
SAMPLER2D(s_alphamask, 0);

void main()
{
	float alpha = texture2D(s_alphamask, v_texcoord0).a;
    if (alpha <= u_alphaRef){
		discard;
	}

	gl_FragDepth = gl_FragCoord.z;
}