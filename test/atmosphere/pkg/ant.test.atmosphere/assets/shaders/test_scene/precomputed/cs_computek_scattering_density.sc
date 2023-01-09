#include <bgfx_compute.sh>

SAMPLER2D(s_transmittance_texture,              0);
SAMPLER3D(s_single_rayleigh_scattering_texture, 1);
SAMPLER3D(s_single_mie_scattering_texture,      2);
SAMPLER3D(s_multiple_scattering_texture,        3);
SAMPLER2D(s_irradiance_texture,                 4);

#define OUPUT_FMT rgba32f

IMAGE3D_WR(s_scattering_density, OUPUT_FMT,       5);

uniform vec4 u_scattering_order;

void main()
{
    ivec3 isize = imageSize(s_transmittance_texture);
    if (any(gl_GlobalInvocationID.xy >= isize.xy))
        return;

    const int layer = gl_GlobalInvocationID.z;
    const int scattering_order = (int)u_scattering_order.x;
    vec3 scattering_density = ComputeScatteringDensityTexture(
        ATMOSPHERE, s_transmittance_texture, s_single_rayleigh_scattering_texture,
        s_single_mie_scattering_texture, s_multiple_scattering_texture,
        s_irradiance_texture, vec3(gl_GlobalInvocationID.xy, layer + 0.5),
        u_scattering_order);

    imageStore(s_scattering_density, gl_GlobalInvocationID.xyz, scattering_density);
}