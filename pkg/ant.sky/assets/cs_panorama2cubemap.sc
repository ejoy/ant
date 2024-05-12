#include <bgfx_compute.sh>

SAMPLER2D(s_source, 0);
IMAGE2D_ARRAY_WO(s_cubemap_source, rgba16f, 1);

#include "common/utils.sh"

uniform vec4 u_param;
#define u_sample_lod u_param.x
#define u_image_width u_param.y
#define u_image_height u_param.z
#define u_image_size u_param.yz

vec3 p2cm(ivec3 id, vec2 size)
{
	vec3 dir = id2dir(id, size);
	vec2 uv = dir2spherecoord(dir);
	return texture2DLod(s_source, uv, 0.0).rgb;
}

NUM_THREADS(32, 32, 1)
void main()
{
    ivec3 size = imageSize(s_cubemap_source);
    imageStore(s_cubemap_source, ivec3(gl_GlobalInvocationID), vec4(p2cm(gl_GlobalInvocationID, vec2(size.xy)), 0.0));
}
