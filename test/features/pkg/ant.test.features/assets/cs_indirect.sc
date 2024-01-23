#include <bgfx_compute.sh>
#include <bgfx_shader.sh>

BUFFER_WR(b_indirect_buffer, uvec4, 0);
uniform vec4 u_mesh_params;

NUM_THREADS(64, 1, 1)
void main()
{
	const uint buffersize = uint(u_mesh_params.x);
    
	uint tid = uint(gl_GlobalInvocationID.x);
	if (tid >= buffersize)
		return ;

	const uint vb_offset = (uint)u_mesh_params.y;
	const uint ib_offset = (uint)u_mesh_params.z;
	const uint ib_num    = (uint)u_mesh_params.w;
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
 
