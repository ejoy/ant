#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

BUFFER_RO(b_mesh_buffer, uvec4, 0);
BUFFER_WR(b_indirect_buffer, uvec4, 1);
uniform vec4 u_mesh_param;

uint calc_ib_offset(uint shape, uint dir)
{
	const uint quadoffset = 6;
	const uint dir_stride = 4 * quadoffset;
	const uint shape_stride = 6 * dir_stride;
	
	return shape * shape_stride + dir * dir_stride;
}

uint load_mesh_info(uint idx){
    uint v4_idx = idx/(4*2);
	uint sub_idx = idx%(4*2);

    uint elem_idx = sub_idx/2;
	uint uint_idx = sub_idx%2;

	vec4 v = b_mesh_buffer[v4_idx];
    uint elem = v[elem_idx];

    return ((elem >> (uint_idx*16)) & 0xffff);
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
	uint shape = mi & 0xff;
	uint dir = (mi>>8) & 0xff;
    const uint vboffset = 0;
    const uint iboffset = calc_ib_offset(shape, dir);

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
 
