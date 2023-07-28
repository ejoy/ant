#include "bgfx_compute.sh"

BUFFER_WR(indirect_buffer, uvec4, 0);

uniform vec4 u_instance_params1;
uniform vec4 u_instance_params2;
uniform vec4 u_instance_params3;
uniform vec4 u_instance_params4;
uniform vec4 u_indirect_params;
uniform vec4 u_mesh_offset;

vec3 get_instance_data(float idx)
{
	if(idx < u_mesh_offset.x){
		return vec3(u_instance_params1.x, u_instance_params1.y, u_instance_params1.z);
	}
	else if(idx < u_mesh_offset.y){
		return vec3(u_instance_params2.x, u_instance_params2.y, u_instance_params2.z);
	}
	else if(idx < u_mesh_offset.z){
		return vec3(u_instance_params3.x, u_instance_params3.y, u_instance_params3.z);
	}
	else {
		return vec3(u_instance_params4.x, u_instance_params4.y, u_instance_params4.z);
	}
}

NUM_THREADS(64, 1, 1)
void main()
{
	int tId = int(gl_GlobalInvocationID.x);
	int numDrawItems = int(u_indirect_params.x);
	int maxToDraw = numDrawItems;
	int indirect_idx = u_indirect_params.y;
	if(tId < maxToDraw)
	{
		vec3 instance_data = get_instance_data(tId);
		drawIndexedIndirect(
						// Target location params:
			indirect_buffer,			// target buffer
			tId,						// index in buffer
						// Draw call params:
			instance_data.z,	// number of indices for this draw call
			1u, 					// number of instances for this draw call. You can disable this draw call by setting to zero
			instance_data.y,	// offset in the index buffer
			instance_data.x,	// offset in the vertex buffer. Note that you can use this to "reindex" submeshses - all indicies in this draw will be decremented by this amount
			tId						// offset in the instance buffer. If you are drawing more than 1 instance per call see gpudrivenrendering for how to handle
		);
	}
	
}
