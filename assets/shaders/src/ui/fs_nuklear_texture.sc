$input v_texcoord0, v_color0

#include "bgfx_shader.sh"

SAMPLER2D(s_texColor, 0);

//uniform sampler2D s_texColor;

void main()
{
	vec4 color = texture2D(s_texColor, v_texcoord0);
	vec4 t_c = color;        
	vec4 v_c = v_color0;     
	gl_FragColor = t_c*v_c;  //color*v_color0;
}
