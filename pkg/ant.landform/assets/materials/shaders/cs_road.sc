#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

BUFFER_RO(b_mesh_buffer, uvec4, 0);
BUFFER_WR(b_indirect_buffer, uvec4, 1);
uniform vec4 u_mesh_param;

uint calc_vb_offset(uint shape, uint dir)
{
	const uint quadoffset = 4;
	return (shape + dir) * quadoffset;
}

uint load_mesh_info(uint tid)
{
	uint v4idx = tid / 4;
	uint v4_subidx = tid % 4;

	uvec4 e = b_mesh_buffer[v4idx];
	return e[v4_subidx];
}

NUM_THREADS(64, 1, 1)
void main()
{
	uint buffersize = uint(u_mesh_param[1]);
	uint tid = uint(gl_GlobalInvocationID.x);
	if (tid > buffersize)
		return ;
	const uint ibnum    = (uint)u_mesh_param[0];
	uint mi = load_mesh_info(tid);
	uint shape = mi & 0xffff;
	uint dir = (mi>>16) & 0xffff;
    const uint vboffset = calc_vb_offset(shape, dir);
    const uint iboffset = 0;

	const uint instanceoffset = tid;
	drawIndexedIndirect(
		b_indirect_buffer,					// target buffer
		tid,								// index in buffer
		ibnum,								// number of indices for this draw call
		1, //queue_visible > 0 ? 1u : 0u,	// number of instances for this draw call. You can disable this draw call by setting to zero
		iboffset,							// offset in the index buffer
		vboffset,							// offset in the vertex buffer. Note that you can use this to "reindex" submeshses - all indicies in this draw will be decremented by this amount
		instanceoffset						// offset in the instance buffer. If you are drawing more than 1 instance per call see gpudrivenrendering for how to handle
	);
}
 
