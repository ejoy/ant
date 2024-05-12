#include <bgfx_compute.sh>
#include <bgfx_shader.sh>

BUFFER_WO(b_visiblity_buffer, vec4, 0);
BUFFER_RO(b_obj_buffer, vec4, 1);
BUFFER_RO(b_plane_buffer, vec4, 2);

vec3 negativeVertex(vec3 bmin, vec3 bmax, vec3 n)
{
	bvec3 b = greaterThan(n, vec3(0.0, 0.0, 0.0));
	return mix(bmin, bmax, b);
}

uint cull(vec3 aabb_min, vec3 aabb_max)
{
	uint queue_visible = 0;
	for(uint i = 0; i < 2; ++i)
	{
		int r = 1;
 		for (int ii = 0; ii < 6 && r >= 0; ++ii)
		{
			vec3 n = negativeVertex(aabb_min, aabb_max, b_plane_buffer[i*6+ii].xyz);
			r = dot(vec4(n, 1.0f), b_plane_buffer[i*6+ii]);
		}	 
		if(r < 0)
		{
			queue_visible &=  ~(1 << i); // is_culled
		}
		else{
			queue_visible |= (1 << i);
		}
	}
	return queue_visible;
}

NUM_THREADS(64, 1, 1)
void main()
{
	int tid = int(gl_GlobalInvocationID.x);
	vec4 aabb_min = b_obj_buffer[2*tid];
	vec4 aabb_max = b_obj_buffer[2*tid+1];
	uint queue_visible = cull(aabb_min.xyz, aabb_max.xyz);
	b_visiblity_buffer[tid] = vec4((float)queue_visible, 0, 0, 0);
}
 
