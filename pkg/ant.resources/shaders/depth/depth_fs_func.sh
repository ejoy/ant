#include <bgfx_shader.sh>
#include "default/inputs_structure.sh"

void CUSTOM_FS_FUNC(in FSInput fs_input, inout FSOutput fs_output)
{
	float depth = fs_input.frag_coord.z;
	float depthSq = depth * depth;
#ifdef PACK_RGBA8
	fs_output.color = vec4(packHalfFloat(depth), packHalfFloat(depthSq));
#else //!PACK_RGBA8
	fs_output.color = vec4_splat(depthSq);
#endif //PACK_RGBA8
}