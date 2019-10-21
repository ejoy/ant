$input v_position
#include "common.sh"

void main()
{
	#ifdef SM_LINEAR
	gl_FragColor.xyz = vec3_splat(v_position.z / v_position.w);
	gl_FragColor.w = 1.0;
	#else
	gl_FragColor = vec4_splat(1.0);
	#endif //SM_LINEAR
}