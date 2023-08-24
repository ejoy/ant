#include <bgfx_shader.sh>
#include "default/inputs_structure.sh"

void CUSTOM_FS_FUNC(in FSInput fsinput, inout FSOutput fsoutput)
{
	float depth = fsinput.frag_coord.z;
	float depthSq = depth * depth;
#ifdef PACK_RGBA8
	fsoutput.color = vec4(packHalfFloat(depth), packHalfFloat(depthSq));
#else //!PACK_RGBA8
	fsoutput.color = vec4_splat(depthSq);
#endif //PACK_RGBA8
}