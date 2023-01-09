#include <bgfx_compute.sh>

#include "../atmosphere.sh"

SAMPLER3D(s_single_rayleigh_scattering_texture, 0);
SAMPLER3D(s_single_mie_scattering_texture,      1);
SAMPLER3D(s_multiple_scattering_texture,        2);

#define OUPUT_FMT rgba32f

IMAGE2D_WR(s_delta_irradiance,  OUPUT_FMT,      3);
IMAGE2D_WR(s_irradiance,        OUPUT_FMT,      4);

uniform mat4 luminance_from_radiance;
uniform vec4 u_scattering_order;

void main()
{
    ivec3 isize = imageSize(s_delta_irradiance);
    if (any(gl_GlobalInvocationID.xy >= isize.xy))
        return;

    const int scattering_order = (int)u_scattering_order.x;
    vec3 delta_irradiance = ComputeIndirectIrradianceTexture(
        ATMOSPHERE, single_rayleigh_scattering_texture,
        single_mie_scattering_texture, multiple_scattering_texture,
        gl_GlobalInvocationID.xy, scattering_order);

    vec3 irradiance = mul(mat3(luminance_from_radiance), delta_irradiance);

    imageStore(s_delta_irradiance,  gl_GlobalInvocationID.xy, vec4(delta_irradiance, 1.0));
    imageStore(s_irradiance,        gl_GlobalInvocationID.xy, vec4(irradiance, 1.0));
}