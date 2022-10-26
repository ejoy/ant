#include <bgfx_compute.sh>
#include <bgfx_shader.sh>
#include "common/camera.sh"
#include "common/shadow.sh"

#ifdef vblur
IMAGE2D_RO(s_image_input, r32f, 0);
#else
IMAGE2D_RO(s_image_input, r32f, 0);
#endif

#define _BLUR9_WEIGHT_0 1.0
#define _BLUR9_WEIGHT_1 0.9
#define _BLUR9_WEIGHT_2 0.55
#define _BLUR9_WEIGHT_3 0.18
#define _BLUR9_WEIGHT_4 0.1
#define _BLUR9_NORMALIZE (_BLUR9_WEIGHT_0+2.0*(_BLUR9_WEIGHT_1+_BLUR9_WEIGHT_2+_BLUR9_WEIGHT_3+_BLUR9_WEIGHT_4) )
#define BLUR9_WEIGHT(_x) (_BLUR9_WEIGHT_##_x/_BLUR9_NORMALIZE)

IMAGE2D_WR(s_image_output, r32f, 1);

uniform vec4 u_blur_offset;

NUM_THREADS(16, 16, 1)
void main()
{
	vec2 size = imageSize(s_image_input);
	vec2 pixel_coord = vec2(gl_GlobalInvocationID.xy);
	if (all(pixel_coord < size)){
		vec4 sum = vec4(0.0, 0.0, 0.0, 0.0);
		vec2 tex0 = pixel_coord;
		vec4 tex1 = vec4(tex0.xy - 1.0 * u_blur_offset.xy, tex0.xy + 1.0 * u_blur_offset.xy) ;
		vec4 tex2 = vec4(tex0.xy - 2.0 * u_blur_offset.xy, tex0.xy + 2.0 * u_blur_offset.xy) ;
		vec4 tex3 = vec4(tex0.xy - 3.0 * u_blur_offset.xy, tex0.xy + 3.0 * u_blur_offset.xy) ;
		vec4 tex4 = vec4(tex0.xy - 4.0 * u_blur_offset.xy, tex0.xy + 4.0 * u_blur_offset.xy) ;

		sum  = imageLoad(s_image_input, tex0)*BLUR9_WEIGHT(0);
		sum += imageLoad(s_image_input, tex1.xy)*BLUR9_WEIGHT(1);
		sum += imageLoad(s_image_input, tex1.zw)*BLUR9_WEIGHT(1);
		sum += imageLoad(s_image_input, tex2.xy)*BLUR9_WEIGHT(2);
		sum += imageLoad(s_image_input, tex2.zw)*BLUR9_WEIGHT(2);
		sum += imageLoad(s_image_input, tex3.xy)*BLUR9_WEIGHT(3);
		sum += imageLoad(s_image_input, tex3.zw)*BLUR9_WEIGHT(3);
		sum += imageLoad(s_image_input, tex4.xy)*BLUR9_WEIGHT(4);
		sum += imageLoad(s_image_input, tex4.zw)*BLUR9_WEIGHT(4);

		imageStore(s_image_output, pixel_coord, sum );
	}
}