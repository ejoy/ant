#include "bgfx_compute.sh"

BUFFER_WR(indirectBuffer, uvec4, 0);
BUFFER_WR(instanceBufferOut, vec4, 1);

uniform vec4 u_heapParams;
uniform vec4 u_meshOffset;
uniform vec4 u_instanceParams;
uniform vec4 u_worldOffset;

NUM_THREADS(64, 1, 1)

void main()
{
	int tId = int(gl_GlobalInvocationID.x);
	int numDrawItems = int(u_heapParams.x);
	float sideSize = u_heapParams.y*1.0;

	int maxToDraw = min(sideSize*sideSize*sideSize, numDrawItems);

	int numToDrawPerThread = maxToDraw/64 + 1;

	int idxStart = tId*numToDrawPerThread;
	int idxMax = min(maxToDraw, (tId+1)*numToDrawPerThread);

	for (int k = idxStart + 1; k <= idxMax; k++) 
    {
        float size2 = sideSize*sideSize;
        int n3 = ceil(k/size2);
        int n2 = ceil((k-(n3-1)*size2)/sideSize);
        int n1 = k-(n3-1)*size2-(n2-1)*sideSize;
		int yy = n3 - 1;
        int zz = n2 - 1;
		int xx = n1 - 1;
        vec4 t = vec4(xx*u_meshOffset.x-u_worldOffset.x, yy*u_meshOffset.y-u_worldOffset.y, zz*u_meshOffset.z-u_worldOffset.z, 1);
		instanceBufferOut[k-1] = t;		
    }

	for (int k = idxStart; k < idxMax; k++) 
	{
		drawIndexedIndirect(
						// Target location params:
			indirectBuffer,			// target buffer
			k,						// index in buffer
						// Draw call params:
			u_instanceParams.w,	// number of indices for this draw call
			1u, 					// number of instances for this draw call. You can disable this draw call by setting to zero
			u_instanceParams.z,	// offset in the index buffer
			u_instanceParams.x,	// offset in the vertex buffer. Note that you can use this to "reindex" submeshses - all indicies in this draw will be decremented by this amount
			k						// offset in the instance buffer. If you are drawing more than 1 instance per call see gpudrivenrendering for how to handle
			);
	}
}
