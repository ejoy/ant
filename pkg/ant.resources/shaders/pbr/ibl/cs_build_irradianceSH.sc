
#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

#include "common/utils.sh"
#include "pbr/ibl/common.sh"

SAMPLERCUBE(s_source, 0);

IMAGE2D_RW(s_irradianceSH, rgba32f, 1);

#define IRRADIANCE_SH_COEFF_NUM (IRRADIANCE_SH_BAND_NUM*IRRADIANCE_SH_BAND_NUM)

/*
 * Area of a cube face's quadrant projected onto a sphere
 *
 *  1 +---+----------+
 *    |   |          |
 *    |---+----------|
 *    |   |(x,y)     |
 *    |   |          |
 *    |   |          |
 * -1 +---+----------+
 *   -1              1
 *
 *
 * The quadrant (-1,1)-(x,y) is projected onto the unit sphere
 *
 */
float sphereQuadrantArea(float x, float y) {
    return atan2(x*y, sqrt(x*x + y*y + 1));
}

float solidAngle(int dim, ivec2 uv)
{
    const float iDim = 1.0f / dim;

    vec2 st = ((uv + 0.5) * 2.0 * iDim)-1.0;

    const vec2 xy0 = st - iDim;
    const vec2 xy1 = st + iDim;

    float solidAngle =  sphereQuadrantArea(xy0.x, xy0.y) -
                        sphereQuadrantArea(xy0.x, xy1.y) -
                        sphereQuadrantArea(xy1.x, xy0.y) +
                        sphereQuadrantArea(xy1.x, xy1.y);
    return solidAngle;
}

int SHindex(int m, int l) {
    return l * (l + 1) + m;
}

struct SHBasics
{
    // max band = 5, coeff number: 5*5
    float data[25];
};

/*
 * Calculates non-normalized SH bases, i.e.:
 *  m > 0, cos(m*phi)   * P(m,l)
 *  m < 0, sin(|m|*phi) * P(|m|,l)
 *  m = 0, P(0,l)
 */
void computeShBasics(inout float SHb[IRRADIANCE_SH_COEFF_NUM], int numBands, vec3 s)
{
#if 0
    // Reference implementation
    float phi = atan2(s.x, s.y);
    for (int l = 0; l < numBands; l++) {
        SHb[SHindex(0, l)] = Legendre(l, 0, s.z);
        for (int m = 1; m <= l; m++) {
            float p = Legendre(l, m, s.z);
            SHb[SHindex(-m, l)] = std::sin(m * phi) * p;
            SHb[SHindex( m, l)] = std::cos(m * phi) * p;
        }
    }
#endif
    /*
     * Below, we compute the associated Legendre polynomials using recursion.
     * see: http://mathworld.wolfram.com/AssociatedLegendrePolynomial.html
     *
     * Note [0]: s.z == cos(theta) ==> we only need to compute P(s.z)
     *
     * Note [1]: We in fact compute P(s.z) / sin(theta)^|m|, by removing
     * the "sqrt(1 - s.z*s.z)" [i.e.: sin(theta)] factor from the recursion.
     * This is later corrected in the ( cos(m*phi), sin(m*phi) ) recursion.
     */

    // s = (x, y, z) = (sin(theta)*cos(phi), sin(theta)*sin(phi), cos(theta))

    // handle m=0 separately, since it produces only one coefficient
    float Pml_2 = 0;
    float Pml_1 = 1;
    SHb[0] =  Pml_1;
    for (int l=1; l<numBands; l++) {
        float Pml = ((2*l-1.0f)*Pml_1*s.z - (l-1.0f)*Pml_2) / l;
        Pml_2 = Pml_1;
        Pml_1 = Pml;
        SHb[SHindex(0, l)] = Pml;
    }
    float Pmm = 1;
    for (int m=1 ; m<numBands ; m++) {
        Pmm = (1.0f - 2*m) * Pmm;      // See [1], divide by sqrt(1 - s.z*s.z);
        Pml_2 = Pmm;
        Pml_1 = (2*m + 1.0f)*Pmm*s.z;
        // l == m
        SHb[SHindex(-m, m)] = Pml_2;
        SHb[SHindex( m, m)] = Pml_2;
        if (m+1 < numBands) {
            // l == m+1
            SHb[SHindex(-m, m+1)] = Pml_1;
            SHb[SHindex( m, m+1)] = Pml_1;
            for (int l=m+2 ; l<numBands ; l++) {
                float Pml = ((2*l - 1.0f)*Pml_1*s.z - (l + m - 1.0f)*Pml_2) / (l-m);
                Pml_2 = Pml_1;
                Pml_1 = Pml;
                SHb[SHindex(-m, l)] = Pml;
                SHb[SHindex( m, l)] = Pml;
            }
        }
    }

    // At this point, SHb contains the associated Legendre polynomials divided
    // by sin(theta)^|m|. Below we compute the SH basis.
    //
    // ( cos(m*phi), sin(m*phi) ) recursion:
    // cos(m*phi + phi) == cos(m*phi)*cos(phi) - sin(m*phi)*sin(phi)
    // sin(m*phi + phi) == sin(m*phi)*cos(phi) + cos(m*phi)*sin(phi)
    // cos[m+1] == cos[m]*s.x - sin[m]*s.y
    // sin[m+1] == sin[m]*s.x + cos[m]*s.y
    //
    // Note that (d.x, d.y) == (cos(phi), sin(phi)) * sin(theta), so the
    // code below actually evaluates:
    //      (cos((m*phi), sin(m*phi)) * sin(theta)^|m|
    float Cm = s.x;
    float Sm = s.y;
    for (int m = 1; m <= numBands; m++) {
        for (int l = m; l < numBands; l++) {
            SHb[SHindex(-m, l)] *= Sm;
            SHb[SHindex( m, l)] *= Cm;
        }
        float Cm1 = Cm * s.x - Sm * s.y;
        float Sm1 = Sm * s.x + Cm * s.y;
        Cm = Cm1;
        Sm = Sm1;
    }
}

NUM_THREADS(WORKGROUP_THREADS, WORKGROUP_THREADS, 1)
void main()
{
    ivec2 size = ivec2(u_cubemap_facesize, u_cubemap_facesize);
    if (any(gl_GlobalInvocationID.xy >= size))
        return ;

    vec3 N = id2dir(gl_GlobalInvocationID, size);

    vec3 color = textureCubeLod(s_source, N, 0).rgb;

    color *= solidAngle(u_cubemap_facesize, gl_GlobalInvocationID.xy);

    //SHBasics SHb = (SHBasics)0;

    float SHb[IRRADIANCE_SH_COEFF_NUM] = {0.0};
    computeShBasics(SHb, IRRADIANCE_SH_BAND_NUM, N);

    for (int i=0 ; i<IRRADIANCE_SH_COEFF_NUM ; ++i) {
        memoryBarrierImage();
        imageStore(s_irradianceSH, ivec2(i, 0), vec4(color * SHb[i], 0.0));
    }
}