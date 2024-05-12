#include <bgfx_compute.sh>

BUFFER_RO(b_instance_frames, uint, 0);
BUFFER_WO(b_indirect_buffer, uvec4,1);

uniform vec4 u_mesh_param;
uniform vec4 u_mesh_param1;

#define u_instance_num  u_mesh_param.w

#define u_frame_offset  u_mesh_param1.x
#define u_frame_num     u_mesh_param1.y

uint which_frame(uint instanceidx)
{
    const uint idx = instanceidx / 4;
    const uint subidx = instanceidx % 4;
    const uint frame_packedidx = b_instance_frames[idx];
    const uint frame = uint((0xff) & (frame_packedidx >> (subidx * 8)));
    return (frame + u_frame_offset) % u_frame_num;
}

NUM_THREADS(64, 1, 1)
void main()
{
    const uint tid = uint(gl_GlobalInvocationID.x);
    if (tid >= u_instance_num)
        return ;

    const float vbnum   = u_mesh_param[0];
    const float ibnum   = u_mesh_param[1];

    const uint frame = which_frame(tid);
    const uint vboffset = vbnum * frame;
    const uint iboffset = 0;
    const uint instanceoffset = tid;
    const uint visible = 1;
    drawIndexedIndirect(
		b_indirect_buffer,					// target buffer
		tid,								// index in buffer
		ibnum,								// number of indices for this draw call
		visible,	                        // number of instances for this draw call. You can disable this draw call by setting to zero
		iboffset,							// offset in the index buffer
		vboffset,							// offset in the vertex buffer. Note that you can use this to "reindex" submeshses - all indicies in this draw will be decremented by this amount
		instanceoffset						// offset in the instance buffer. If you are drawing more than 1 instance per call see gpudrivenrendering for how to handle
	);
}