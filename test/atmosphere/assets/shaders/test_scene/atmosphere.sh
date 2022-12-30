#ifndef __ATMOSPHERE_SH__
#define __ATMOSPHERE_SH__

#define IN(x) const in x
#define OUT(x) out x
#define TEMPLATE(x)
#define TEMPLATE_ARGUMENT(x)
#define assert(x)

uniform vec4 SKY_SPECTRAL_RADIANCE_TO_LUMINANCE;
uniform vec4 SUN_SPECTRAL_RADIANCE_TO_LUMINANCE;

#define TRANSMITTANCE_TEXTURE_WIDTH SKY_SPECTRAL_RADIANCE_TO_LUMINANCE.w

#define TRANSMITTANCE_TEXTURE_HEIGHT SUN_SPECTRAL_RADIANCE_TO_LUMINANCE.w

uniform vec4 SCATTERING_TEXTURE_SIZE;

#define SCATTERING_TEXTURE_R_SIZE       SCATTERING_TEXTURE_SIZE.x
#define SCATTERING_TEXTURE_MU_SIZE      SCATTERING_TEXTURE_SIZE.y
#define SCATTERING_TEXTURE_MU_S_SIZE    SCATTERING_TEXTURE_SIZE.z
#define SCATTERING_TEXTURE_NU_SIZE      SCATTERING_TEXTURE_SIZE.w

uniform vec4 IRRADIANCE_TEXTURE_SIZE;
#define IRRADIANCE_TEXTURE_WIDTH        IRRADIANCE_TEXTURE_SIZE.x
#define IRRADIANCE_TEXTURE_HEIGHT       IRRADIANCE_TEXTURE_SIZE.y

#define COMBINED_SCATTERING_TEXTURES

#include "definitions.sh"

#define u_amtosphere_params[14];

#define solar_irradiance    u_amtosphere_params[0].rgb
#define sun_angular_radius  u_amtosphere_params[0].a

#define bottom_radius       u_amtosphere_params[1].x
#define top_radius          u_amtosphere_params[1].y


float amtosphere_value(int offset)
{
    int idx = offset / 4;
    int subidx = offset % 4;

    return u_amtosphere_params[idx][subidx];
}

#define rayleigh_density_profile_start  6
#define rayleigh_density_profile_end    rayleigh_density_profile_start+10

#define rayleigh_scattering_start   rayleigh_density_profile_end
#define rayleigh_scattering_end     rayleigh_scattering_start+3

#define mie_density_profile_start   rayleigh_scattering_end
#define mie_density_profile_end mie_density_profile_start+10

#define mie_scattering_start   mie_density_profile_end
#define mie_scattering_end     mie_scattering_start+3

#define mie_extinction_start   mie_scattering_end
#define mie_extinction_end     mie_extinction_start+3

#define mie_phase_function_g    mie_extinction_end

#define absorption_density_profile_start    mie_phase_function_g+1
#define absorption_density_profile_end      absorption_density_profile_start+10

#define absorption_extinction_start absorption_density_profile_end
#define absorption_extinction_end absorption_extinction_start+3

#define ground_albedo_start absorption_extinction_end
#define ground_albedo_end ground_albedo_start+3

#define mu_s_min    ground_albedo_end

DensityProfile to_rayleigh_density_profile()
{
    DensityProfile dp;
    dp.layer[0] = DesityProfileLayer(
        amtosphere_value(rayleigh_density_profile_start),
        amtosphere_value(rayleigh_density_profile_start+1),
        amtosphere_value(rayleigh_density_profile_start+2),
        amtosphere_value(rayleigh_density_profile_start+3),
        amtosphere_value(rayleigh_density_profile_start+4));

    dp.layer[1] = DesityProfileLayer(
        amtosphere_value(rayleigh_density_profile_start+5),
        amtosphere_value(rayleigh_density_profile_start+6),
        amtosphere_value(rayleigh_density_profile_start+7),
        amtosphere_value(rayleigh_density_profile_start+8),
        amtosphere_value(rayleigh_density_profile_start+9));

    return dp;
}

vec3 rayleigh_scattering()
{
    return vec3(
        amtosphere_value(rayleigh_scattering_start),
        amtosphere_value(rayleigh_scattering_start+1),
        amtosphere_value(rayleigh_scattering_start+2));
}


DensityProfile to_mie_density_profile()
{
    DensityProfile dp;
    dp.layer[0] = DesityProfileLayer(
        amtosphere_value(mie_density_profile_start),
        amtosphere_value(mie_density_profile_start+1),
        amtosphere_value(mie_density_profile_start+2),
        amtosphere_value(mie_density_profile_start+3),
        amtosphere_value(mie_density_profile_start+4));

    dp.layer[1] = DesityProfileLayer(
        amtosphere_value(mie_density_profile_start+5),
        amtosphere_value(mie_density_profile_start+6),
        amtosphere_value(mie_density_profile_start+7),
        amtosphere_value(mie_density_profile_start+8),
        amtosphere_value(mie_density_profile_start+9));

    return dp;
}

vec3 mie_scattering()
{
    return vec3(
        amtosphere_value(mie_scattering_start),
        amtosphere_value(mie_scattering_start+1),
        amtosphere_value(mie_scattering_start+2));
}

vec3 mie_extinction()
{
    return vec3(
        amtosphere_value(mie_extinction_start),
        amtosphere_value(mie_extinction_start+1),
        amtosphere_value(mie_extinction_start+2));
}

DensityProfile to_absorption_density_profile()
{
    DensityProfile dp;
    dp.layer[0] = DesityProfileLayer(
        amtosphere_value(absorption_density_profile_start),
        amtosphere_value(absorption_density_profile_start+1),
        amtosphere_value(absorption_density_profile_start+2),
        amtosphere_value(absorption_density_profile_start+3),
        amtosphere_value(absorption_density_profile_start+4));

    dp.layer[1] = DesityProfileLayer(
        amtosphere_value(absorption_density_profile_start+5),
        amtosphere_value(absorption_density_profile_start+6),
        amtosphere_value(absorption_density_profile_start+7),
        amtosphere_value(absorption_density_profile_start+8),
        amtosphere_value(absorption_density_profile_start+9));

    return dp;
}

vec3 absorption_extinction()
{
    return vec3(
        amtosphere_value(absorption_extinction_start),
        amtosphere_value(absorption_extinction_start+1),
        amtosphere_value(absorption_extinction_start+2));
}

vec3 ground_albedo()
{
    return vec3(
        amtosphere_value(ground_albedo_start),
        amtosphere_value(ground_albedo_start+1),
        amtosphere_value(ground_albedo_start+2));
}

const AtmosphereParameters ATMOSPHERE = AtmosphereParameters(
    solar_irradiance,
    sun_angular_radius,
    bottom_radius,
    top_radius,
    to_rayleigh_density_profile(),
    rayleigh_scattering(),
    to_mie_density_profile(),
    mie_scattering(),
    mie_extinction(),
    atmosphere_value(mie_phase_function_g),
    to_absorption_density_profile(),
    absorption_extinction(),
    ground_albedo(),
    atmosphere_value(mu_s_min));


#include "functions.sh"

#endif //__ATMOSPHERE_SH__