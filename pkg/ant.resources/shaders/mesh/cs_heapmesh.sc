#include "bgfx_compute.sh"

BUFFER_WR(indirectBuffer, uvec4, 0);
BUFFER_WR(instanceBufferOut, vec4, 1);

uniform vec4 u_heapParams;
uniform vec4 u_meshOffset;
uniform vec4 u_instanceParams;
uniform vec4 u_worldOffset;
uniform vec4 u_specialParam;

NUM_THREADS(64, 1, 1)

void main()
{
	int tId = int(gl_GlobalInvocationID.x);
	int numDrawItems = int(u_heapParams.x);
	float sizeX = u_heapParams.y*1.0;
	float sizeY = u_heapParams.z*1.0;
	float sizeZ = u_heapParams.w*1.0;
	int maxToDraw = min(sizeX*sizeY*sizeZ, numDrawItems);
	if(tId < maxToDraw)
	{
		float sizeXZ = sizeX*sizeZ;
		int k = tId + 1;
		int n3 = ceil(k/sizeXZ);
		int n2 = ceil((k-(n3-1)*sizeXZ)/sizeX);
		int n1 = k-(n3-1)*sizeXZ-(n2-1)*sizeX;
		float yy = n3 - 1.0;
		float zz = n2 - 1.0;
		float xx = n1 - 1.0;
		float tx = xx * u_meshOffset.x - u_worldOffset.x;
		float ty = yy * u_meshOffset.y;
		float tz = zz * u_meshOffset.z - u_worldOffset.z;
		vec4 t = vec4(tx, ty, tz, 1);
		instanceBufferOut[tId] = t;
		drawIndexedIndirect(
						// Target location params:
			indirectBuffer,			// target buffer
			tId,						// index in buffer
						// Draw call params:
			u_instanceParams.w,	// number of indices for this draw call
			1u, 					// number of instances for this draw call. You can disable this draw call by setting to zero
			u_instanceParams.z,	// offset in the index buffer
			u_instanceParams.x,	// offset in the vertex buffer. Note that you can use this to "reindex" submeshses - all indicies in this draw will be decremented by this amount
			tId						// offset in the instance buffer. If you are drawing more than 1 instance per call see gpudrivenrendering for how to handle
		);
		if(tId == 44){
			instanceBufferOut[tId] = u_specialParam;
		} 
	}
	
}
 
