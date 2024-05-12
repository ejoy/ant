#include "bgfx_compute.sh"

BUFFER_WO(indirect_buffer, uvec4, 0);
BUFFER_WO(instance_buffer, vec4, 1);

uniform vec4 u_instance_params;
uniform vec4 u_indirect_params;

NUM_THREADS(64, 1, 1)

void main()
{
	int tId = int(gl_GlobalInvocationID.x);
	int numDrawItems = int(u_indirect_params.x);
	int maxToDraw = numDrawItems;
	if(tId < maxToDraw)
	{
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
 
