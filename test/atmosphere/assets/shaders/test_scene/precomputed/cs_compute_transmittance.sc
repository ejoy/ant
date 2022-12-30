#include <bgfx_shader.sh>

#include "../atmosphere.sh"

IMAGE2D_RO(s_transmittance, rgb32f, 0);

void main() {
    ivec3 isize = imageSize(s_result);
    if (any(gl_GlobalInvocationID.xy >= isize.xy))
        return;
    vec3 t = ComputeTransmittanceToTopAtmosphereBoundaryTexture(
        ATMOSPHERE, gl_GlobalInvocationID.xy);
    imageStore(s_transmittance, gl_GlobalInvocationID.xy, t);
}