#include <bgfx_compute.sh>
#include <bgfx_shader.sh>

#ifndef SUB_MESH_COUNT
#define SUB_MESH_COUNT 4
#endif //SUB_MESH_COUNT

BUFFER_RO(b_mesh_indices,    uint, 0);
BUFFER_WR(b_indirect_buffer, uvec4, 1);
uniform vec4 u_buffer_param;
uniform vec4 u_mesh_params[SUB_MESH_COUNT];

uint load_mesh_idx(uint idx){
	uint bufidx = idx / 2;
	uint uint16_idx = idx % 2;
	uint v = b_mesh_indices[bufidx];

	return ((v >> (uint16_idx*16)) & 0xffff);
}

NUM_THREADS(64, 1, 1)
void main()
{
	const uint buffersize = uint(u_buffer_param.x);
	const uint tid = uint(gl_GlobalInvocationID.x);
	if (tid >= buffersize)
		return ;
	const uint meshidx = load_mesh_idx(tid);

	const vec4 vboffsets = u_mesh_params[0];
	const vec4 iboffsets = u_mesh_params[1];
	const vec4 ibnums    = u_mesh_params[2];

	const uint vb_offset = (uint)vboffsets[meshidx];
	const uint ib_offset = (uint)iboffsets[meshidx];
	const uint ib_num    = (uint)ibnums[meshidx];

	const uint instanceoffset = tid;
	drawIndexedIndirect(
		b_indirect_buffer,					// target buffer
		tid,								// index in buffer
		ib_num,								// number of indices for this draw call
		1, //queue_visible > 0 ? 1u : 0u,	// number of instances for this draw call. You can disable this draw call by setting to zero
		ib_offset,							// offset in the index buffer
		vb_offset,							// offset in the vertex buffer. Note that you can use this to "reindex" submeshses - all indicies in this draw will be decremented by this amount
		instanceoffset						// offset in the instance buffer. If you are drawing more than 1 instance per call see gpudrivenrendering for how to handle
	);
}
 
