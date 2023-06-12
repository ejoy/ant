#include "bgfx_compute.sh"

BUFFER_WR(indirect_buffer, uvec4, 0);
BUFFER_WR(instance_buffer, vec4, 1);

uniform vec4 u_heap_params;
uniform vec4 u_aabb_size;
uniform vec4 u_interval_size;
uniform vec4 u_instance_params;

NUM_THREADS(64, 1, 1)

void main()
{
	int tId = int(gl_GlobalInvocationID.x);
	int numDrawItems = int(u_heap_params.x);
	float sizeX = u_heap_params.y;
	float sizeY = u_heap_params.z;
	float sizeZ = u_heap_params.w;
	int maxToDraw = min(sizeX * sizeY * sizeZ, numDrawItems);
	float world_offset_x = (sizeX - 1) * 0.5 * (1 + u_interval_size.x) * u_aabb_size.x;
	float world_offset_z = (sizeZ - 1) * 0.5 * (1 + u_interval_size.z) * u_aabb_size.z;
	if(tId < maxToDraw)
	{
		float sizeXZ = sizeX * sizeZ;
		int k = tId + 1;
		int n3 = ceil(k / sizeXZ);
		int n2 = ceil((k - (n3 - 1) * sizeXZ) / sizeX);
		int n1 = k - (n3 - 1) * sizeXZ - (n2 - 1) * sizeX;
		float yy = n3 - 1.0;
		float zz = n2 - 1.0;
		float xx = n1 - 1.0;
		float tx = xx * (1 + u_interval_size.x) * u_aabb_size.x - world_offset_x;
		float ty = yy * (1 + u_interval_size.y) * u_aabb_size.y ;
		float tz = zz * (1 + u_interval_size.z) * u_aabb_size.z - world_offset_z;
		vec4 t = vec4(tx, ty, tz, 1);
		instance_buffer[tId * 3 + 2] = t;
		drawIndexedIndirect(
						// Target location params:
			indirect_buffer,			// target buffer
			tId,						// index in buffer
						// Draw call params:
			u_instance_params.w,	// number of indices for this draw call
			1u, 					// number of instances for this draw call. You can disable this draw call by setting to zero
			u_instance_params.z,	// offset in the index buffer
			u_instance_params.x,	// offset in the vertex buffer. Note that you can use this to "reindex" submeshses - all indicies in this draw will be decremented by this amount
			tId						// offset in the instance buffer. If you are drawing more than 1 instance per call see gpudrivenrendering for how to handle
		);
	}
	
}
 
