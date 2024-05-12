#include <bgfx_compute.sh>
#include <bgfx_shader.sh>

BUFFER_RO(b_visiblity_buffer, vec4, 0);
BUFFER_WO(b_indirect_buffer,   uvec4, 1);
BUFFER_RO(b_indirect_params_buffer, vec4, 2);
BUFFER_RO(b_obj_buffer, vec4, 3);

uniform vec4 u_queue_params;
#define queue_mask u_queue_params.x

NUM_THREADS(64, 1, 1)
void main()
{
	int tid = int(gl_GlobalInvocationID.x);
	uint visible_mask = (uint)(b_visiblity_buffer[tid].x);
	uint queue_visible = (1 << (uint)queue_mask) & visible_mask;
	float mesh_idx = b_obj_buffer[2*tid].w - 1; //lua
	vec4 indirect_params = b_indirect_params_buffer[mesh_idx];
	float vb_offset = indirect_params.x;
	float ib_offset = indirect_params.y;
	float ib_num = indirect_params.z;
	drawIndexedIndirect(
		b_indirect_buffer,			   // target buffer
		tid,						   // index in buffer
		ib_num,                  	   // number of indices for this draw call
		queue_visible > 0 ? 1u : 0u,   // number of instances for this draw call. You can disable this draw call by setting to zero
		ib_offset,	                   // offset in the index buffer
		vb_offset,	                   // offset in the vertex buffer. Note that you can use this to "reindex" submeshses - all indicies in this draw will be decremented by this amount
		tid			                   // offset in the instance buffer. If you are drawing more than 1 instance per call see gpudrivenrendering for how to handle
	);
}
 
