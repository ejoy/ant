#include <bgfx_compute.sh>
#include <bgfx_shader.sh>
#include "common/camera.sh"
#include "common/shadow.sh"

#ifdef vblur
IMAGE2D_RO(s_image_input, r32f, 0);
#else
IMAGE2D_RO(s_image_input, r32f, 0);
#endif

#define _BLUR9_WEIGHT_0 1.0  / 4.46
#define _BLUR9_WEIGHT_1 0.9  / 4.46
#define _BLUR9_WEIGHT_2 0.55 / 4.46
#define _BLUR9_WEIGHT_3 0.18 / 4.46
#define _BLUR9_WEIGHT_4 0.1  / 4.46

IMAGE2D_WR(s_image_output, r32f, 1);

NUM_THREADS(16, 16, 1)
void main()
{
	vec2 size = imageSize(s_image_input);
	vec2 pixel_coord = vec2(gl_GlobalInvocationID.xy);
	if (pixel_coord.x < size.x && pixel_coord.y < size.y){
		vec4 sum = vec4(0.0, 0.0, 0.0, 0.0);

		for (int i = 0; i < 9; ++i)
		{
			float weight;
			int j = i - 4;
			if(j == 0){
				weight = _BLUR9_WEIGHT_0;
			}
			else if(j == -1 || j == 1){
				weight = _BLUR9_WEIGHT_1;
			}
			else if(j == -2 || j == 2){
				weight = _BLUR9_WEIGHT_2;
			}
			else if(j == -3 || j == 3){
				weight = _BLUR9_WEIGHT_3;
			}
			else{
				weight = _BLUR9_WEIGHT_4;
			}

			#ifdef vblur
				vec2 pc = pixel_coord + vec2(0.0, 1.0) * j;
			#else
				vec2 pc = pixel_coord + vec2(1.0, 0.0) * j;
			#endif

			if (pc.x < 0) pc.x = 0;
			if (pc.y < 0) pc.y = 0;
			if (pc.x >= size.x) pc.x = size.x - 1;
			if (pc.y >= size.y) pc.y = size.y - 1;

			#ifdef vblur
				float depth = imageLoad(s_image_input, pc).x;
				//float depthSq = depth * depth;
				sum.x += depth * weight;
				//sum.y += depthSq * weight;
			#else
				sum += imageLoad(s_image_input, pc) * weight;
			#endif	
		}
		imageStore(s_image_output, pixel_coord, sum );
	}
}