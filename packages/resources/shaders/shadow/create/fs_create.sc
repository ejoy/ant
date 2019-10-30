$input v_position
#include "common.sh"

uniform vec4 u_depth_scale_offset;

void main()
{
	#ifdef SM_LINEAR
	float depth = (v_position.z / v_position.w) * u_depth_scale_offset.x + u_depth_scale_offset.y;
	gl_FragColor = packFloatToRgba(depth);
	#else
	gl_FragColor = vec4_splat(1.0);
	#endif //SM_LINEAR
}