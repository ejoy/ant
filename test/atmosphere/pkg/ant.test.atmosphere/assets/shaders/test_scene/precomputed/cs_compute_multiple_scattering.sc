#include <bgfx_compute.sh>

#include "../atmosphere.sh"

// layout(location = 0) out vec3 delta_multiple_scattering;
// layout(location = 1) out vec4 scattering;

uniform mat3 luminance_from_radiance;
SAMPLER2D(s_transmittance_texture,                  0);
SAMPLER3D(s_scattering_density_texture,             1);

#define OUTPUT_FMT rgba32f

IMAGE3D_WR(s_delta_multiple_scattering,   OUTPUT_FMT, 2);
IMAGE3D_WR(s_scattering,                  OUTPUT_FMT, 3);

void main()
{
    const ivec3 isize = imageSize(s_delta_multiple_scattering);
    if (any(gl_GlobalInvocationID.xy >= isize.xy))
        return;

    const int layer = gl_GlobalInvocationID.z;

    float nu;
    vec3 delta_multiple_scattering = ComputeMultipleScatteringTexture(
        ATMOSPHERE, s_transmittance_texture, s_scattering_density_texture,
        vec3(gl_GlobalInvocationID.xy, layer + 0.5), nu);
    vec4 scattering = vec4(
        luminance_from_radiance *
            delta_multiple_scattering.rgb / RayleighPhaseFunction(nu),
        0.0);

    imageStore(s_delta_multiple_scattering, gl_GlobalInvocationID.xyz, delta_multiple_scattering);
    imageStore(s_scattering, gl_GlobalInvocationID.xyz, scattering);
}