#include <bgfx_compute.sh>
#include <bgfx_shader.sh>

#ifndef SUB_MESH_COUNT
#define SUB_MESH_COUNT 4
#endif //SUB_MESH_COUNT

BUFFER_RO(b_mesh_indices,    uvec4, 0);
BUFFER_WR(b_indirect_buffer, uvec4, 1);
uniform vec4 u_buffer_param;
uniform vec4 u_mesh_params[SUB_MESH_COUNT];

uint load_mesh_idx(uint idx){
    uint v4_idx = idx/(4*2);
	uint sub_idx = idx%(4*2);

    uint elem_idx = sub_idx/2;
	uint uint_idx = sub_idx%2;

	uvec4 v = b_mesh_indices[v4_idx];
    uint elem = v[elem_idx];

    return ((elem >> (uint_idx*16)) & 0xffff);
}

NUM_THREADS(64, 1, 1)
void main()
{
	uint buffersize = uint(u_buffer_param.x);
	uint tid = uint(gl_GlobalInvocationID.x);
	if (tid > buffersize)
		return ;
	uint meshidx = load_mesh_idx(tid);

	vec4 vbnums = u_mesh_params[0];
	vec4 ibnums = u_mesh_params[1];
	uvec4 vboffsets = uvec4(0, uvec3(vbnums.xyz));
	uvec4 iboffsets = uvec4(0, uvec3(ibnums.xyz));

	float vb_offset = vboffsets[meshidx];
	float ib_offset = iboffsets[meshidx];
	float ib_num    = ibnums[meshidx];

	uint srtoffset_invec4 = 3; // 3 * vec4
	uint instanceoffset = tid * srtoffset_invec4;
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
 
