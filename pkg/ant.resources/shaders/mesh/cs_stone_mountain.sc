#include "bgfx_compute.sh"

BUFFER_WR(b_indirect_vb, uvec4, 0);
BUFFER_RO(b_visibility_vb, vec4, 1);

uniform vec4 u_instance_params;
uniform vec4 u_indirect_params;

NUM_THREADS(64, 1, 1)

void main()
{
	int tId = int(gl_GlobalInvocationID.x);
	int numDrawItems = int(u_indirect_params.x);
	int maxToDraw = numDrawItems;
	int indirect_idx = u_indirect_params.y;
	if(tId < maxToDraw)
	{

		vec4 visibility = b_visibility_vb[tId];
		for(int i = 0; i < 3; ++i){
			int is_visible = 0;
			if(visibility[i] == 1.0){
				is_visible = 1;
			}
			drawIndexedIndirect(
							// Target location params:
				b_indirect_vb,			// target buffer
				tId * 3 + i,						// index in buffer
							// Draw call params:
				u_instance_params.w,	// number of indices for this draw call
				is_visible, 					// number of instances for this draw call. You can disable this draw call by setting to zero
				u_instance_params.z,	// offset in the index buffer
				u_instance_params.x,	// offset in the vertex buffer. Note that you can use this to "reindex" submeshses - all indicies in this draw will be decremented by this amount
				tId * 3 + i						// offset in the instance buffer. If you are drawing more than 1 instance per call see gpudrivenrendering for how to handle
			);					
		}
	}
	
}
