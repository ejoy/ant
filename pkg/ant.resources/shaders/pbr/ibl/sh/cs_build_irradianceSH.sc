
#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

#ifdef ENABLE_IRRADIANCE_SH
#include "common/utils.sh"
#include "pbr/ibl/common.sh"

#include "pbr/ibl/sh/common.sh"

SAMPLERCUBE(s_source, 0);

IMAGE2D_WO(s_irradianceSH, rgba32f, 1);

struct SH_basic {
    float v[IRRADIANCE_SH_COEFF_NUM];
};

struct SH_Yml {
    vec3 Yml[IRRADIANCE_SH_COEFF_NUM];
};

SH_basic get_SH_basic()
{
    SH_basic s = (SH_basic)0;

    const float INV_PI      = 1.0 / M_PI;
    const float SQRT_PI     = sqrt(M_PI);
    const float INV_SQRT_PI = 1.0 / SQRT_PI;

    const float L1_f = 0.5 * M_PI;

    const float L2_f = sqrt(3.0/(4.0*M_PI));
    const float sq15 = sqrt(15.0);
    const float sq5  = sqrt(5.0);

    const float L3_f1 = sq15*INV_SQRT_PI*0.5 ;//math.sqrt(15.0/( 4.0*pi))
    const float L3_f2 = sq5 *INV_SQRT_PI*0.25;//math.sqrt( 5.0/(16.0*pi))
    const float L3_f3 = sq15*INV_SQRT_PI*0.25;//math.sqrt(15.0/(16.0*pi))

    s.v[0] = L1_f;

#if IRRADIANCE_SH_COEFF_NUM == 2
    s.v[1] = -L2_f;
    s.v[2] =  L2_f;
    s.v[3] = -L2_f;
#elif IRRADIANCE_SH_COEFF_NUM == 3
    s.v[4] =  L3_f1;
    s.v[5] = -L3_f1;
    s.v[6] =  L3_f2;
    s.v[7] = -L3_f1;
    s.v[8] =  L3_f3;
#endif //IRRADIANCE_SH_COEFF_NUM != 2/3
    return s;
}

SH_basic calc_Yml(N)
{
    SH_basic s = get_SH_basic();

    SH_basic Yml = (SH_basic)0;
    Yml.v[0] = s.v[0];
    
    const float x = N.x, y = N.y, z = N.z;

#if IRRADIANCE_SH_COEFF_NUM == 2
    Yml.v[2] = s.v[2]*y;
    Yml.v[3] = s.v[3]*z;
    Yml.v[4] = s.v[4]*x;
#elif IRRADIANCE_SH_COEFF_NUM == 3

    Yml.v[5] = s.v[5]*y*x;
    Yml.v[6] = s.v[6]*y*z;
    Yml.v[7] = s.v[7]*(3.0*z*z-1.0);
    Yml.v[8] = s.v[8]*x*z;
    Yml.v[9] = s.v[9]*(x*x-y*y);
#endif //IRRADIANCE_SH_COEFF_NUM != 2/3

    return Yml;
}

struct Lml{
    vec3 v[IRRADIANCE_SH_BAND_NUM];
};

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
float sphereQuadrantArea(float x, float y)
{
    return atan(x*y, sqrt(x*x + y*y + 1.0));
}

float solidAngle(float dim, uint iu, uint iv)
{
    const float idiam = 1.0 / dim;
    float s = ((iu + 0.5) * 2.0 * idim)-1.0;
    float t = ((iv + 0.5) * 2.0 * idim)-1.0;

    float x0, y0 = s-idim, t-idim;
    float x1, y1 = s+idim, t+idim;

    return  sphereQuadrantArea(x0, y0) -
            sphereQuadrantArea(x0, y1) -
            sphereQuadrantArea(x1, y0) +
            sphereQuadrantArea(x1, y1);
}

//we rearrange 6 cubemap face into 1 x 6
NUM_THREADS(WORKGROUP_THREADS, WORKGROUP_THREADS, 1)
void main()
{
    ivec2 size = ivec2(u_facesize, u_facesize);
    if (size <= gl_GlobalInvocationID.xy)
        return ;

    const int face = gl_GlobalInvocationID.z;

    const ivec2 out_uv = ivec2(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y + face * u_facesize);

    vec3 N = id2dir(gl_GlobalInvocationID, size);

    vec3 color      = textureCubeLod(s_source, N, 0);
    vec3 radiance   = color * solidAngle(u_facesize, gl_GlobalInvocationID.xy);
    SH_basic Yml    = calc_Yml(N);

    for (int i=0; i<IRRADIANCE_SH_COEFF_NUM; ++i)
    {
        imageStore(s_irradianceSH, ivec2(out_uv.x * IRRADIANCE_SH_COEFF_NUM + i, out_uv.y), radiance * Yml.v[i]);
    }
}
#else //!ENABLE_IRRADIANCE_SH
NUM_THREADS(1, 1, 1)
void main()
{

}
#endif //ENABLE_IRRADIANCE_SH