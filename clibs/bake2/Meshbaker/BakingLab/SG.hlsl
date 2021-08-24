//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include <Constants.hlsl>
#include "BRDF.hlsl"

// SphericalGaussian(dir) := Amplitude * exp(Sharpness * (dot(Axis, dir) - 1.0f))
struct SG
{
    float3 Amplitude;
    float3 Axis;
    float Sharpness;
};

// AnisotropicSphericalGaussian(dir) :=
//    Amplitude * exp(-SharpnessX * dot(BasisX, dir)^2 - SharpnessY * dot(BasisY, dir)^2)
struct ASG
{
    float3 Amplitude;
    float3 BasisZ;              // Direction the ASG points
    float3 BasisX;
    float3 BasisY;
    float SharpnessX;           // Scale of the X axis
    float SharpnessY;           // Scale of the Y axis
};

//-------------------------------------------------------------------------------------------------
// Evaluates an SG given a direction on a unit sphere
//-------------------------------------------------------------------------------------------------
float3 EvaluateSG(in SG sg, in float3 dir)
{
    return sg.Amplitude * exp(sg.Sharpness * (dot(dir, sg.Axis) - 1.0f));
}

//-------------------------------------------------------------------------------------------------
// Evaluates an ASG given a direction on a unit sphere
//-------------------------------------------------------------------------------------------------
float3 EvaluateASG(in ASG asg, in float3 dir)
{
    float smoothTerm = saturate(dot(asg.BasisZ, dir));
    float lambdaTerm = asg.SharpnessX * dot(dir, asg.BasisX) * dot(dir, asg.BasisX);
    float muTerm = asg.SharpnessY * dot(dir, asg.BasisY) * dot(dir, asg.BasisY);
    return asg.Amplitude * smoothTerm * exp(-lambdaTerm - muTerm);
}

//-------------------------------------------------------------------------------------------------
// Computes the vector product of two SG's, which produces a new SG. If the new SG is evaluated,
// with a direction 'v' the result is equal to SGx(v) * SGy(v).
//-------------------------------------------------------------------------------------------------
SG SGProduct(in SG x, in SG y)
{
    float3 um = (x.Sharpness * x.Axis + y.Sharpness * y.Axis) / (x.Sharpness + y.Sharpness);
    float umLength = length(um);
    float lm = x.Sharpness + y.Sharpness;

    SG res;
    res.Axis = um * (1.0f / umLength);
    res.Sharpness = lm * umLength;
    res.Amplitude = x.Amplitude * y.Amplitude * exp(lm * (umLength - 1.0f));

    return res;
}

//-------------------------------------------------------------------------------------------------
// Computes the integral of an SG over the entire sphere
//-------------------------------------------------------------------------------------------------
float3 SGIntegral(in SG sg)
{
    float expTerm = 1.0f - exp(-2.0f * sg.Sharpness);
    return 2 * Pi * (sg.Amplitude / sg.Sharpness) * expTerm;
}

//-------------------------------------------------------------------------------------------------
// Computes the approximate integral of an SG over the entire sphere. The error vs. the
// non-approximate version decreases as sharpeness increases.
//-------------------------------------------------------------------------------------------------
float3 ApproximateSGIntegral(in SG sg)
{
    return 2 * Pi * (sg.Amplitude / sg.Sharpness);
}

//-------------------------------------------------------------------------------------------------
// Computes the inner product of two SG's, which is equal to Integrate(SGx(v) * SGy(v) * dv).
//-------------------------------------------------------------------------------------------------
float3 SGInnerProduct(in SG x, in SG y)
{
    float umLength = length(x.Sharpness * x.Axis + y.Sharpness * y.Axis);
    float3 expo = exp(umLength - x.Sharpness - y.Sharpness) * x.Amplitude * y.Amplitude;
    float other = 1.0f - exp(-2.0f * umLength);
    return (2.0f * Pi * expo * other) / umLength;
}

//-------------------------------------------------------------------------------------------------
// Convolve an SG with an ASG
//-------------------------------------------------------------------------------------------------
float3 ConvolveASG_SG(in ASG asg, in SG sg) {
    // The ASG paper specifes an isotropic SG as exp(2 * nu * (dot(v, axis) - 1)),
    // so we must divide our SG sharpness by 2 in order to get the nup parameter expected by
    // the ASG formulas
    float nu = sg.Sharpness * 0.5f;

    ASG convolveASG;
    convolveASG.BasisX = asg.BasisX;
    convolveASG.BasisY = asg.BasisY;
    convolveASG.BasisZ = asg.BasisZ;

    convolveASG.SharpnessX = (nu * asg.SharpnessX) / (nu + asg.SharpnessX);
    convolveASG.SharpnessY = (nu * asg.SharpnessY) / (nu + asg.SharpnessY);

    convolveASG.Amplitude = Pi / sqrt((nu + asg.SharpnessX) * (nu + asg.SharpnessY));

    return EvaluateASG(convolveASG, sg.Axis) * sg.Amplitude * asg.Amplitude;
}

//-------------------------------------------------------------------------------------------------
// Returns an approximation of the clamped cosine lobe represented as an SG
//-------------------------------------------------------------------------------------------------
SG CosineLobeSG(in float3 direction)
{
    SG cosineLobe;
    cosineLobe.Axis = direction;
    cosineLobe.Sharpness = 2.133f;
    cosineLobe.Amplitude = 1.17f;

    return cosineLobe;
}

//-------------------------------------------------------------------------------------------------
// Returns an SG approximation of the GGX NDF used in the specular BRDF. For a single-lobe
// approximation, the resulting NDF actually more closely resembles a Beckmann NDF.
//-------------------------------------------------------------------------------------------------
SG DistributionTermSG(in float3 direction, in float roughness)
{
    SG distribution;
    distribution.Axis = direction;
    float m2 = roughness * roughness;
    distribution.Sharpness = 2 / m2;
    distribution.Amplitude = 1.0f / (Pi * m2);

    return distribution;
}

//-------------------------------------------------------------------------------------------------
// Computes the approximate incident irradiance from a single SG lobe containing incoming radiance.
// The clamped cosine lobe is approximated as an SG, and convolved with the incoming radiance
// lobe using an SG inner product
//-------------------------------------------------------------------------------------------------
float3 SGIrradianceInnerProduct(in SG lightingLobe, in float3 normal)
{
    SG cosineLobe = CosineLobeSG(normal);
    return max(SGInnerProduct(lightingLobe, cosineLobe), 0.0f);
}

//-------------------------------------------------------------------------------------------------
// Computes the approximate incident irradiance from a single SG lobe containing incoming radiance.
// The SG is treated as a punctual light, with intensity equal to the integral of the SG.
//-------------------------------------------------------------------------------------------------
float3 SGIrradiancePunctual(in SG lightingLobe, in float3 normal)
{
    float cosineTerm = saturate(dot(lightingLobe.Axis, normal));
    return cosineTerm * 2.0f * Pi * (lightingLobe.Amplitude) / lightingLobe.Sharpness;
}

//-------------------------------------------------------------------------------------------------
// Computes the approximate incident irradiance from a single SG lobe containing incoming radiance.
// The irradiance is computed using a fitted approximation polynomial. This approximation
// and its implementation were provided by Stephen Hill.
//-------------------------------------------------------------------------------------------------
float3 SGIrradianceFitted(in SG lightingLobe, in float3 normal)
{
    const float muDotN = dot(lightingLobe.Axis, normal);
    const float lambda = lightingLobe.Sharpness;

    const float c0 = 0.36f;
    const float c1 = 1.0f / (4.0f * c0);

    float eml  = exp(-lambda);
    float em2l = eml * eml;
    float rl   = rcp(lambda);

    float scale = 1.0f + 2.0f * em2l - rl;
    float bias  = (eml - em2l) * rl - em2l;

    float x  = sqrt(1.0f - scale);
    float x0 = c0 * muDotN;
    float x1 = c1 * x;

    float n = x0 + x1;

    float y = (abs(x0) <= x1) ? n * n / x : saturate(muDotN);

    float normalizedIrradiance = scale * y + bias;

    return normalizedIrradiance * ApproximateSGIntegral(lightingLobe);
}

//-------------------------------------------------------------------------------------------------
// Computes the outputgoing radiance from a single SG lobe containing incoming radiance, using
// a Lambertian diffuse BRDF.
//-------------------------------------------------------------------------------------------------
float3 SGDiffuseInnerProduct(in SG lightingLobe, in float3 normal, in float3 albedo)
{
    float3 brdf = albedo / Pi;
    return SGIrradianceInnerProduct(lightingLobe, normal) * brdf;
}

//-------------------------------------------------------------------------------------------------
// Computes the outputgoing radiance from a single SG lobe containing incoming radiance, using
// a Lambertian diffuse BRDF.
//-------------------------------------------------------------------------------------------------
float3 SGDiffusePunctual(in SG lightingLobe, in float3 normal, in float3 albedo)
{
    float3 brdf = albedo / Pi;
    return SGIrradiancePunctual(lightingLobe, normal) * brdf;
}

//-------------------------------------------------------------------------------------------------
// Computes the outputgoing radiance from a single SG lobe containing incoming radiance, using
// a Lambertian diffuse BRDF.
//-------------------------------------------------------------------------------------------------
float3 SGDiffuseFitted(in SG lightingLobe, in float3 normal, in float3 albedo)
{
    float3 brdf = albedo / Pi;
    return SGIrradianceFitted(lightingLobe, normal) * brdf;
}

//-------------------------------------------------------------------------------------------------
// Generate an SG that best represents the NDF SG but with it's axis oriented in the direction
// of the current BRDF slice. This will allow easier integration, because the SG\ASG are both
// in the same domain. Uses the warping operator from Wang et al.
//-------------------------------------------------------------------------------------------------
SG WarpDistributionSG(in SG ndf, in float3 view)
{
    SG warp;

    warp.Axis = reflect(-view, ndf.Axis);
    warp.Amplitude = ndf.Amplitude;
    warp.Sharpness = ndf.Sharpness / (4.0f * max(dot(ndf.Axis, view), 0.1f));

    return warp;
}

//-------------------------------------------------------------------------------------------------
// Generate an ASG that best represents the NDF SG but with it's axis oriented in the direction
// of the current BRDF slice. This will allow easier integration, because the SG\ASG are both
// in the same domain.
//
// The warped NDF can be represented better as an ASG, so following Kun Xu from
// 'Anisotropic Spherical Gaussians' we change the SG to an ASG because the distribution of
// an NDF stretches at grazing angles.
//-------------------------------------------------------------------------------------------------
ASG WarpDistributionASG(in SG ndf, in float3 view)
{
    ASG warp;

    // Generate any orthonormal basis with Z pointing in the direction of the reflected view vector
    warp.BasisZ = reflect(-view, ndf.Axis);
    warp.BasisX = normalize(cross(ndf.Axis, warp.BasisZ));
    warp.BasisY = normalize(cross(warp.BasisZ, warp.BasisX));

    float dotdiro = max(dot(view, ndf.Axis), 0.1f);

    // Second derivative of the sharpness with respect to how far we are from basis Axis direction
    warp.SharpnessX = ndf.Sharpness / (8.0f * dotdiro * dotdiro);
    warp.SharpnessY = ndf.Sharpness / 8.0f;

    warp.Amplitude = ndf.Amplitude;

    return warp;
}

//-------------------------------------------------------------------------------------------------
// Computes the specular reflectance from a single SG lobe containing incoming radiance
//-------------------------------------------------------------------------------------------------
float3 SpecularTermSGWarp(in SG light, in float3 normal, in float roughness,
                          in float3 view, in float3 specAlbedo)
{
    // Create an SG that approximates the NDF. Note that a single SG lobe is a poor fit for
    // the GGX NDF, since the GGX distribution has a longer tail. A sum of 3 SG's can more
    // closely match the shape of a GGX distribution, but it would also increase the cost
    // computing specular by a factor of 3.
    SG ndf = DistributionTermSG(normal, roughness);

    // Apply a warpring operation that will bring the SG from the half-angle domain the the
    // the lighting domain. The resulting lobe is another SG.
    SG warpedNDF = WarpDistributionSG(ndf, view);

     // Convolve the NDF with the SG light
    float3 output = SGInnerProduct(warpedNDF, light);

    // Parameters needed for evaluating the visibility term
    float m2 = roughness * roughness;
    float nDotL = saturate(dot(normal, warpedNDF.Axis));
    float nDotV = saturate(dot(normal, view));
    float3 h = normalize(warpedNDF.Axis + view);

    // The visibility term is evaluated at the center of our warped BRDF lobe
    output *= GGX_V1(m2, nDotL) * GGX_V1(m2, nDotV);

    // Fresnel evaluated at the center of our warped BRDF lobe
    output *= specAlbedo + (1.0f - specAlbedo) * pow((1.0f - saturate(dot(warpedNDF.Axis, h))), 5.0f);

    // Fade out spec entirely when lower than 0.1% albedo
    output *= saturate(dot(specAlbedo, 333.0f));

    // Cosine term evaluated at the center of our warped BRDF lobe
    output *= nDotL;

    return max(output, 0.0f);
}

//-------------------------------------------------------------------------------------------------
// Computes the specular reflectance from a single SG lobe containing incoming radiance
//-------------------------------------------------------------------------------------------------
float3 SpecularTermASGWarp(in SG light, in float3 normal, in float roughness,
                           in float3 view, in float3 specAlbedo)
{
    // Create an SG that approximates the NDF. Note that a single SG lobe is a poor fit for
    // the GGX NDF, since the GGX distribution has a longer tail. A sum of 3 SG's can more
    // closely match the shape of a GGX distribution, but it would also increase the cost
    // computing specular by a factor of 3.
    SG ndf = DistributionTermSG(normal, roughness);

    // Apply a warpring operation that will bring the SG from the half-angle domain the the
    // the lighting domain. The resulting lobe is an ASG that's stretched along the viewing
    // direction in order to better match the actual shape of a GGX distribution.
    ASG warpedNDF = WarpDistributionASG(ndf, view);

    // Convolve the NDF with the light. Note, this is a integration of the NDF which is an ASG
    // with the light which is a SG. See Kun Xu 'Anisotropic Spherical Gaussians' section 4.3
    // for more details
    float3 output = ConvolveASG_SG(warpedNDF, light);

    // Parameters needed for evaluating the visibility term
    float m2 = roughness * roughness;
    float nDotL = saturate(dot(normal, warpedNDF.BasisZ));
    float nDotV = saturate(dot(normal, view));
    float3 h = normalize(warpedNDF.BasisZ + view);

    // The visibility term is evaluated at the center of our warped BRDF lobe
    output *= GGX_V1(m2, nDotL) * GGX_V1(m2, nDotV);

    // Fresnel evaluated at the center of our warped BRDF lobe
    output *= specAlbedo + (1.0f - specAlbedo) * pow((1.0f - saturate(dot(warpedNDF.BasisZ, h))), 5.0f);

    // Fade out spec entirely when lower than 0.1% albedo
    output *= saturate(dot(specAlbedo, 333.0f));

    // Cosine term evaluated at the center of our warped BRDF lobe
    output *= nDotL;

    return max(output, 0.0f);
}

//-------------------------------------------------------------------------------------------------
// Computes an SG sharpness value such that all values within theta radians of the SG axis have
// a value greater than epsilon
//-------------------------------------------------------------------------------------------------
float SGSharpnessFromThreshold(in float amplitude, in float epsilon, in float cosTheta)
{
    return (log(epsilon) - log(amplitude)) / (cosTheta - 1.0f);
}

//-------------------------------------------------------------------------------------------------
// Returns an SG that can serve as an approximation for the incoming radiance from a spherical
// area light source
//-------------------------------------------------------------------------------------------------
SG MakeSphereSG(in float3 lightDir, in float radius, in float3 intensity, in float dist)
{
    SG sg;

    float r2 = radius * radius;
    float d2 = dist * dist;

    float lne = -2.230258509299f; // ln(0.1)
    sg.Axis = normalize(lightDir);
    sg.Sharpness = (-lne * d2) / r2;
    sg.Amplitude = intensity;

    return sg;
}