#include <bgfx_compute.sh>
#include <bgfx_shader.sh>
#include "common/camera.sh"
#include "common/shadow.sh"

IMAGE2D_RO(s_image_input,  rgba8, 0);
IMAGE2D_WR(s_image_output, rgba8, 1);

#define _BLUR9_WEIGHT_0 1.0
#define _BLUR9_WEIGHT_1 0.9
#define _BLUR9_WEIGHT_2 0.55
#define _BLUR9_WEIGHT_3 0.18
#define _BLUR9_WEIGHT_4 0.1
#define _BLUR9_NORMALIZE (_BLUR9_WEIGHT_0+2.0*(_BLUR9_WEIGHT_1+_BLUR9_WEIGHT_2+_BLUR9_WEIGHT_3+_BLUR9_WEIGHT_4) )
#define BLUR9_WEIGHT(_x) (_BLUR9_WEIGHT_##_x/_BLUR9_NORMALIZE)


uniform vec4 u_blur_offset;
uniform vec4 u_coeffs[9];

NUM_THREADS(16, 16, 1)
void main()
{

	ivec2 size = imageSize(s_image_input);
	ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);

	if (pixel_coord.x < size.x && pixel_coord.y < size.y)
	{
		vec4 sum = vec4(0.0, 0.0, 0.0, 0.0);

		for (int i = 0; i < 33; ++i)
		{
			ivec2 pc = pixel_coord + u_blur_offset.xy * (i - 16);
			if (pc.x < 0) pc.x = 0;
			if (pc.y < 0) pc.y = 0;
			if (pc.x >= size.x) pc.x = size.x - 1;
			if (pc.y >= size.y) pc.y = size.y - 1;

			sum += u_coeffs[i/4][i%4] * imageLoad(s_image_input, pc);
		}

		imageStore(s_image_output, pixel_coord, sum);
	}
}