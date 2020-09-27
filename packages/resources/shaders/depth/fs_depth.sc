$input v_position
#include "common.sh"
#ifdef DEPTH_LINEAR
uniform vec4 u_depth_scale_offset;
#endif 

void main()
{
# ifdef DEPTH_LINEAR
	float depth = (v_position.z / v_position.w);// * u_depth_scale_offset.x + u_depth_scale_offset.y;
#   ifdef PACK_RGBA8
	gl_FragColor = packFloatToRgba(depth);
#   else
	gl_FragColor = vec4(depth, 0.0, 0.0, 0.0);
#   endif
# else //!DEPTH_LINEAR
	gl_FragColor = vec4_splat(1.0);
# endif //DEPTH_LINEAR
}