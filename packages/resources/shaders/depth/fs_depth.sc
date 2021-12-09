#include <bgfx_shader.sh>

void main()
{
	float depth = gl_FragCoord.z;
#ifdef PACK_RGBA8
	gl_FragColor = packFloatToRgba(depth);
#else //!PACK_RGBA8
	gl_FragColor = vec4_splat(depth);
#endif //PACK_RGBA8
}