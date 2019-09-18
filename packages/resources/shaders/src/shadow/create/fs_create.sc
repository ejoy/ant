$input v_position
#include "common.sh"

void main()
{
	gl_FragColor.xyz = vec3(1.0, 0.0, 0.0);//vec3_splat(v_position.z / v_position.w);
	gl_FragColor.w = 1.0;
}