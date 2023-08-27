#include <bgfx_compute.sh>
#include <bgfx_shader.sh>

BUFFER_WR(b_visiblity_buffer, vec4, 0);
BUFFER_RO(b_obj_buffer, vec4, 1);
BUFFER_RO(b_plane_buffer, vec4, 2);

int plane_intersect(vec4 plane, vec3 min, vec3 max)
{
	float minD, maxD;
	if (plane.x > 0.0f) {
		minD = plane.x * min.x;
		maxD = plane.x * max.x;
	}
	else {
		minD = plane.x * max.x;
		maxD = plane.x * min.x;
	}

	if (plane.y > 0.0f) {
		minD += plane.y * min.y;
		maxD += plane.y * max.y;
	}
	else {
		minD += plane.y * max.y;
		maxD += plane.y * min.y;
	}

	if (plane.z > 0.0f) {
		minD += plane.z * min.z;
		maxD += plane.z * max.z;
	}
	else {
		minD += plane.z * max.z;
		maxD += plane.z * min.z;
	}

	// in front of the plane
	if (minD > -plane.w) {
		return 1;
	}

	// in back of the plane
	if (maxD < -plane.w) {
		return -1;
	}

	// straddle of the plane
	return 0;
}

uint cull(vec3 aabb_min, vec3 aabb_max)
{
	uint queue_visible = 0;
	for(uint i = 0; i < 2; ++i)
	{
		int r = 1;
		for (uint ii = 0; ii < 6; ++ii)
		{
			vec4 plane = b_plane_buffer[i*6+ii];
			int t = plane_intersect(plane, aabb_min, aabb_max);
			r = t < r ? t : r;
			if (r < 0)
			{
				break;
			}
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
 
