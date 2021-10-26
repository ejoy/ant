#include "common/inputs.sh"
#include "common/inputs.sh"
#ifdef WITH_COLOR_ATTRIB
$input OUTPUT_COLOR0
#else //!WITH_COLOR_ATTRIB
uniform vec4 u_color;
#endif //WITH_COLOR_ATTRIB

#include <bgfx_shader.sh>



void main()
{
#ifdef WITH_COLOR_ATTRIB
	gl_FragColor = v_color0;
#else //!WITH_COLOR_ATTRIB
	gl_FragColor = u_color;
#endif //WITH_COLOR_ATTRIB
}