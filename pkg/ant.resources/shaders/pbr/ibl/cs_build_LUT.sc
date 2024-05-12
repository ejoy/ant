#include <bgfx_compute.sh>
#include <pbr/ibl/common.sh>

IMAGE2D_WO(s_LUT_write, rg16f, 0);

// From the filament docs. Geometric Shadowing function
// https://google.github.io/filament/Filament.html#toc4.4.2
float V_SmithGGXCorrelated(float NoV, float NoL, float roughness)
{
    float a2 = pow(roughness, 4.0);
    float GGXV = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
    float GGXL = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
    return 0.5 / (GGXV + GGXL);
}


vec2 LUT(float NdotV, float roughness)
{
    // Compute spherical view vector: (sin(phi), 0, cos(phi))
    vec3 V = vec3(sqrt(1.0 - NdotV * NdotV), 0.0, NdotV);

    // The macro surface normal just points up.
    vec3 N = vec3(0.0, 0.0, 1.0);

    // To make the LUT independant from the material's F0, which is part of the Fresnel term
    // when substituted by Schlick's approximation, we factor it out of the integral,
    // yielding to the form: F0 * I1 + I2
    // I1 and I2 are slighlty different in the Fresnel term, but both only depend on
    // NoL and roughness, so they are both numerically integrated and written into two channels.
    vec2 AB = vec2_splat(0.0);
    for(int i = 0; i < int(u_sample_count); ++i)
    {
        // Importance sampling, depending on the distribution.
        vec3 H = importance_sample_GGX(i, N, roughness).xyz;
        vec3 L = normalize(reflect(-V, H));

        float NdotL = saturate(L.z);
        float NdotH = saturate(H.z);
        float VdotH = saturate(dot(V, H));
        if (NdotL > 0.0)
        {
            // LUT for GGX distribution.

            // Taken from: https://bruop.github.io/ibl
            // Shadertoy: https://www.shadertoy.com/view/3lXXDB
            // Terms besides V are from the GGX PDF we're dividing by.
            float V_pdf = V_SmithGGXCorrelated(NdotV, NdotL, roughness) * VdotH * NdotL / NdotH;
            float Fc = pow(1.0 - VdotH, 5.0);
            AB.x += (1.0 - Fc) * V_pdf;
            AB.y += Fc * V_pdf;
        }
    }

    // The PDF is simply pdf(v, h) -> NDF * <nh>.
    // To parametrize the PDF over l, use the Jacobian transform, yielding to: pdf(v, l) -> NDF * <nh> / 4<vh>
    // Since the BRDF divide through the PDF to be normalized, the 4 can be pulled out of the integral.
    return 4.0 * AB / float(u_sample_count);
}

NUM_THREADS(WORKGROUP_THREADS, WORKGROUP_THREADS, 1)
void main()
{
    ivec2 isize = imageSize(s_LUT_write);
    vec2 uv = gl_GlobalInvocationID.xy / vec2(isize);
    float NdotV = uv.x;
    float roughness = max(uv.y, MIN_ROUGHNESS);

    vec2 AB = LUT(NdotV, roughness);

    // Scale and Bias for F0 (as per Karis 2014)
    imageStore(s_LUT_write, ivec2(gl_GlobalInvocationID.xy), vec4(AB, 0.0, 0.0));
}
