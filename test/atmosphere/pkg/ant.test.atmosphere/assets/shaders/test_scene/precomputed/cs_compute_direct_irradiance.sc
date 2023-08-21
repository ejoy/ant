#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

#include "../atmosphere.sh"

SAMPLER2D(s_transmittance_texture, 0);

IMAGE_WR(s_delta_irradiance, rgb32f, 1);
IMAGE_WR(s_irradiance_write, rgb32f, 2);

NUM_THREADS(16, 16, 1)
void main()
{
    ivec3 isize = imageSize(s_delta_irradiance);
    if (any(gl_GlobalInvocationID.xy >= isize.xy))
        return;

    vec3 delta_irradiance = ComputeDirectIrradianceTexture(
        ATMOSPHERE, s_transmittance_texture, gl_GlobalInvocationID.xy);
    imageStore(s_delta_irradiance, gl_GlobalInvocationID.xy, delta_irradiance);


    vec3 irradiance = vec3_splat(0.0);
    //TODO: ?
    imageStore(s_irradiance_write, gl_GlobalInvocationID.xy, irradiance); 
}