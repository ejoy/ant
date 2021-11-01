#ifdef DEPTH_LINEAR
$input v_position
uniform vec4 u_depth_scale_offset;
#endif //DEPTH_LINEAR
#include "common.sh"
void main()
{
# ifdef DEPTH_LINEAR
	float depth = (v_position.z / v_position.w);// * u_depth_scale_offset.x + u_depth_scale_offset.y;
#   ifdef PACK_RGBA8
	gl_FragColor = packFloatToRgba(depth);
#   else
	gl_FragColor = vec4_splat(depth);
#   endif
# else //!DEPTH_LINEAR
	gl_FragColor = vec4_splat(1.0);
# endif //DEPTH_LINEAR
}