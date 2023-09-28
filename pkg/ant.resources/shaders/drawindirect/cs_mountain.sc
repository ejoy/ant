#include <bgfx_compute.sh>
#include <bgfx_shader.sh>

#ifndef SUB_MESH_COUNT
#define SUB_MESH_COUNT 4
#endif //SUB_MESH_COUNT

BUFFER_RO(b_mesh_indices,    uvec4, 0);
BUFFER_WR(b_indirect_buffer, uvec4, 1);

uniform vec4 u_mesh_params[SUB_MESH_COUNT];

uint load_mesh_idx(uint idx){
    uint v4_idx = idx/(4*2);

    vec4 v = b_mesh_indices[v4_idx];

    uint sub_idx = idx % (4*2);

    uint elem_idx = sub_idx/2;
    uint elem = v[elem_idx];

    uint uint_idx = elem_idx % 2;
    uint indices[] = {elem & 0xffff, elem>>16};
    return indices[uint_idx];
}

NUM_THREADS(64, 1, 1)
void main()
{
	uint tid = uint(gl_GlobalInvocationID.x);
	uint meshidx = load_mesh_idx(tid);

	vec4 p = u_mesh_params[meshidx];
	float vb_offset = p.x;
	float ib_offset = p.y;
	float ib_num    = p.z;

	drawIndexedIndirect(
		b_indirect_buffer,			   // target buffer
		tid,						   // index in buffer
		ib_num,                  	   // number of indices for this draw call
		1, //queue_visible > 0 ? 1u : 0u,   // number of instances for this draw call. You can disable this draw call by setting to zero
		ib_offset,	                   // offset in the index buffer
		vb_offset,	                   // offset in the vertex buffer. Note that you can use this to "reindex" submeshses - all indicies in this draw will be decremented by this amount
		tid			                   // offset in the instance buffer. If you are drawing more than 1 instance per call see gpudrivenrendering for how to handle
	);
}
 
