#include <bgfx_shader.sh>

void main()
{
	float depth = gl_FragCoord.z;
	float depthSq = depth * depth;
#ifdef PACK_RGBA8
	//gl_FragColor = packFloatToRgba(depth);
	gl_FragColor = vec4(packHalfFloat(depth), packHalfFloat(depthSq));
#else //!PACK_RGBA8
	gl_FragColor = vec4_splat(depthSq);
	//gl_FragColor = vec4(depth, depthSq, 0, 0);
#endif //PACK_RGBA8
}