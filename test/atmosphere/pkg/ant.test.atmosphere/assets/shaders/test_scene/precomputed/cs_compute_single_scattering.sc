#include <bgfx_shader.sh>

#incldue "../atmosphere.sh"

SAMPLER2D(s_transmittance_texture, 0);

#define OUTPUT_FMT  rgba32f

IMAGE3D_WR(s_delta_rayleigh,        OUTPUT_FMT, 1);
IMAGE3D_WR(s_delta_mie,             OUTPUT_FMT, 2);
IMAGE3D_WR(s_scattering,            OUTPUT_FMT, 3);
IMAGE3D_WR(s_single_mie_scattering, OUTPUT_FMT, 4);

uniform mat4 u_luminance_from_radiance;

NUM_THREADS(16, 16, 1)
void main()
{
    ivec3 isize = imageSize(s_delta_irradiance);
    if (any(gl_GlobalInvocationID.xy >= isize.xy))
        return;

    const int layer = gl_GlobalInvocationID.z;
    vec3 delta_rayleigh, delta_mie;
    ComputeSingleScatteringTexture(
        ATMOSPHERE, s_transmittance_texture, vec3(gl_GlobalInvocationID.xy, u_layer.x + 0.5),
        delta_rayleigh, delta_mie);
    
    mat3 l_from_r = mat3(u_luminance_from_radiance);

    vec3 scattering = vec4(
                        mul(l_from_r, delta_rayleigh),
                        mul(l_from_r, delta_mie).r);
    vec3 single_mie_scattering = mul(l_from_r, delta_mie);

    imageStore(s_delta_rayleigh, delta_raleigh, gl_GlobalInvocationID.xyz);
}