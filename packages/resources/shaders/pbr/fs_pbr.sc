$output v_normal, v_posWS, v_texcoord0
#include <bgfx_shader.sh>
#include "common/lighting.sh"

uniform vec4 u_IBLparam;
#define u_prefilteredCubeMipLevels IBLparam.x
#define u_scaleIBLAmbient IBLparam.y


// material properites
SAMPLER2D(s_basecolor, 0);
uniform vec4 u_basecolor_factor;

SAMPLER2D(s_metallic_roughness, 1);
uniform vec4 u_metallic_roughness_factor;
#define u_metallic_factor   u_metallic_roughness_factor.x
#define u_roughness_factor  u_metallic_roughness_factor.y

SAMPLER2D(s_normal, 2);

SAMPLER2D(s_occlusion, 3);

SAMPLER2D(s_emissive, 4);
uniform vec4 u_emissive_factor;

uniform vec4 u_material_texture_flags;
#define u_basecolor_texture_flag    u_material_texture_flags.x
#define u_metallic_roughness_texture_flag u_metallic_roughness_factor.z
#define u_normal_texture_flag       u_material_texture_flags.y
#define u_occlusion_texture_flag    u_material_texture_flags.z
#define u_emissive_texture_flag     u_material_texture_flags.w

uniform vec4 u_diffuse_factor;
uniform vec4 u_specular_factor;

// IBL
SAMPLERCUBE(s_irradiance, 6);
SAMPLERCUBE(s_prefilteredmap, 7);
SAMPLER2D(s_BRDFLUT, 8);

// alpha
uniform vec4 u_alpha_info;
#define u_alpha_mask u_alpha_info.x
#define u_alpha_mask_cutoff u_alpha_info.y

// Encapsulate the various inputs used by the various functions in the shading equation
// We store values in this struct to simplify the integration of alternative implementations
// of the shading terms, outlined in the Readme.MD Appendix.
struct PBRInfo
{
	float NdotL;                  // cos angle between normal and light direction
	float NdotV;                  // cos angle between normal and view direction
	float NdotH;                  // cos angle between normal and half vector
	float LdotH;                  // cos angle between light direction and half vector
	float VdotH;                  // cos angle between view direction and half vector
	float perceptualRoughness;    // roughness value, as authored by the model creator (input to shader)
	float metalness;              // metallic value at the surface
	vec3 reflectance0;            // full reflectance color (normal incidence angle)
	vec3 reflectance90;           // reflectance color at grazing angle
	float alphaRoughness;         // roughness mapped to a more linear change in the roughness (proposed by [2])
	vec3 diffuseColor;            // color contribution from diffuse lighting
	vec3 specularColor;           // color contribution from specular lighting
};

const float M_PI = 3.141592653589793;
const float c_MinRoughness = 0.04;

const float PBR_WORKFLOW_METALLIC_ROUGHNESS = 0.0;
const float PBR_WORKFLOW_SPECULAR_GLOSINESS = 1.0f;


// vec3 Uncharted2Tonemap(vec3 color)
// {
// 	float A = 0.15;
// 	float B = 0.50;
// 	float C = 0.10;
// 	float D = 0.20;
// 	float E = 0.02;
// 	float F = 0.30;
// 	float W = 11.2;
// 	return ((color*(A*color+C*B)+D*E)/(color*(A*color+B)+D*F))-E/F;
// }

// vec4 tonemap(vec4 color)
// {
// 	vec3 outcol = Uncharted2Tonemap(color.rgb * uboParams.exposure);
// 	outcol = outcol * (1.0f / Uncharted2Tonemap(vec3(11.2f)));	
// 	return vec4(pow(outcol, vec3(1.0f / uboParams.gamma)), color.a);
// }

// Find the normal for this fragment, pulling either from a predefined normal map
// or from the interpolated mesh normal and tangent attributes.
vec3 getNormal(vec3 normal_WS, vec4 posWS, vec2 texcoord)
{
    if (u_normal_texture_flag > 1.0){
	    // Perturb normal, see http://www.thetenthplanet.de/archives/1180
        vec3 normal_TS = texture(s_normal, v_texcoord0).xyz * 2.0 - 1.0;

        vec3 q1 = dFdx(posWS);
        vec3 q2 = dFdy(posWS);
        vec2 st1 = dFdx(texcoord);
        vec2 st2 = dFdy(texcoord);

        vec3 N = normalize(normal_WS);
        vec3 T = normalize(q1 * st2.t - q2 * st1.t);
        vec3 B = -normalize(cross(N, T));
        mat3 TBN = mat3(T, B, N);

        return normalize(TBN * normal_TS);
    }

    return normalize(normal_WS);
}

// Calculation of the lighting contribution from an optional Image Based Light source.
// Precomputed Environment Maps are required uniform inputs and are computed as outlined in [1].
// See our README.md on Environment Maps [3] for additional discussion.
vec3 getIBLContribution(PBRInfo pbrInputs, vec3 n, vec3 reflection)
{
	float lod = (pbrInputs.perceptualRoughness * u_prefilteredCubeMipLevels);
	// retrieve a scale and bias to F0. See [1], Figure 3
	vec3 brdf = (texture(samplerBRDFLUT, vec2(pbrInputs.NdotV, 1.0 - pbrInputs.perceptualRoughness))).rgb;
	vec3 diffuseLight = toLinear(tonemap(texture(samplerIrradiance, n))).rgb;
	vec3 specularLight = toLinear(tonemap(textureLod(prefilteredMap, reflection, lod))).rgb;

	vec3 diffuse = diffuseLight * pbrInputs.diffuseColor;
	vec3 specular = specularLight * (pbrInputs.specularColor * brdf.x + brdf.y);

	// For presentation, this allows us to disable IBL terms
	// For presentation, this allows us to disable IBL terms
	diffuse *= u_scaleIBLAmbient;
	specular *= u_scaleIBLAmbient;

	return diffuse + specular;
}

// Basic Lambertian diffuse
// Implementation from Lambert's Photometria https://archive.org/details/lambertsphotome00lambgoog
// See also [1], Equation 1
vec3 diffuse(PBRInfo pbrInputs)
{
	return pbrInputs.diffuseColor / M_PI;
}

// The following equation models the Fresnel reflectance term of the spec equation (aka F())
// Implementation of fresnel from [4], Equation 15
vec3 specularReflection(PBRInfo pbrInputs)
{
	return pbrInputs.reflectance0 + (pbrInputs.reflectance90 - pbrInputs.reflectance0) * pow(clamp(1.0 - pbrInputs.VdotH, 0.0, 1.0), 5.0);
}

// This calculates the specular geometric attenuation (aka G()),
// where rougher material will reflect less light back to the viewer.
// This implementation is based on [1] Equation 4, and we adopt their modifications to
// alphaRoughness as input as originally proposed in [2].
float geometricOcclusion(PBRInfo pbrInputs)
{
	float NdotL = pbrInputs.NdotL;
	float NdotV = pbrInputs.NdotV;
	float r = pbrInputs.alphaRoughness;

	float attenuationL = 2.0 * NdotL / (NdotL + sqrt(r * r + (1.0 - r * r) * (NdotL * NdotL)));
	float attenuationV = 2.0 * NdotV / (NdotV + sqrt(r * r + (1.0 - r * r) * (NdotV * NdotV)));
	return attenuationL * attenuationV;
}

// The following equation(s) model the distribution of microfacet normals across the area being drawn (aka D())
// Implementation from "Average Irregularity Representation of a Roughened Surface for Ray Reflection" by T. S. Trowbridge, and K. P. Reitz
// Follows the distribution function recommended in the SIGGRAPH 2013 course notes from EPIC Games [1], Equation 3.
float microfacetDistribution(PBRInfo pbrInputs)
{
	float roughnessSq = pbrInputs.alphaRoughness * pbrInputs.alphaRoughness;
	float f = (pbrInputs.NdotH * roughnessSq - pbrInputs.NdotH) * pbrInputs.NdotH + 1.0;
	return roughnessSq / (M_PI * f * f);
}

vec4 get_basecolor(texcoord)
{
    if (u_basecolor_texture_flag > 0) {
		baseColor = toLinear(texture(s_basecolor, texcoord)) * u_basecolor_factor;
	} else {
		baseColor = u_basecolor_factor;
	}
}

void main()
{
	vec4 baseColor;

	vec3 f0 = vec3(0.04);

	if (u_alpha_mask == 1.0f) {
		baseColor = get_basecolor(v_texcoord0);
		if (baseColor.a < u_alphaMaskCutoff) {
			discard;
		}
	}

    // Metallic and Roughness material properties are packed together
    // In glTF, these factors can be specified by fixed scalar values
    // or from a metallic-roughness map
    float perceptualRoughness = u_roughness_factor;
    float metallic    = u_metallic_factor;
    if (u_metallic_roughness_texture_flag > 1.0) {
        // Roughness is stored in the 'g' channel, metallic is stored in the 'b' channel.
        // This layout intentionally reserves the 'r' channel for (optional) occlusion map data
        vec4 mrSample = texture(physicalDescriptorMap, v_texcoord0);
        perceptualRoughness = mrSample.g * perceptualRoughness;
        metallic = mrSample.b * metallic;
    } else {
        perceptualRoughness = clamp(perceptualRoughness, c_MinRoughness, 1.0);
        metallic = clamp(metallic, 0.0, 1.0);
    }
    // Roughness is authored as perceptual roughness; as is convention,
    // convert to material roughness by squaring the perceptual roughness [2].

    // The albedo may be defined from a base texture or a flat color
    baseColor = get_basecolor(v_texcoord0);

	vec3 diffuseColor = baseColor.rgb * (vec3(1.0) - f0);
	diffuseColor *= 1.0 - metallic;
		
	float alphaRoughness = perceptualRoughness * perceptualRoughness;

	vec3 specularColor = mix(f0, baseColor.rgb, metallic);

	// Compute reflectance.
	float reflectance = max(max(specularColor.r, specularColor.g), specularColor.b);

	// For typical incident reflectance range (between 4% to 100%) set the grazing reflectance to 100% for typical fresnel effect.
	// For very low reflectance range on highly diffuse objects (below 4%), incrementally reduce grazing reflecance to 0%.
	float reflectance90 = clamp(reflectance * 25.0, 0.0, 1.0);
	vec3 specularEnvironmentR0 = specularColor.rgb;
	vec3 specularEnvironmentR90 = vec3(1.0, 1.0, 1.0) * reflectance90;

	vec3 n = getNormal(v_normal, v_posWS, v_texcoord0);
	vec3 v = normalize(u_eyePos - v_posWS);    // Vector from surface point to camera
	vec3 l = normalize(directional_lightdir[0].xyz);     // Vector from surface point to light
	vec3 h = normalize(l+v);                        // Half vector between both l and v
	vec3 reflection = -normalize(reflect(v, n));
	reflection.y *= -1.0f;

	float NdotL = clamp(dot(n, l), 0.001, 1.0);
	float NdotV = clamp(abs(dot(n, v)), 0.001, 1.0);
	float NdotH = clamp(dot(n, h), 0.0, 1.0);
	float LdotH = clamp(dot(l, h), 0.0, 1.0);
	float VdotH = clamp(dot(v, h), 0.0, 1.0);

	PBRInfo pbrInputs = PBRInfo(
		NdotL,
		NdotV,
		NdotH,
		LdotH,
		VdotH,
		perceptualRoughness,
		metallic,
		specularEnvironmentR0,
		specularEnvironmentR90,
		alphaRoughness,
		diffuseColor,
		specularColor
	);

	// Calculate the shading terms for the microfacet specular shading model
	vec3 F = specularReflection(pbrInputs);
	float G = geometricOcclusion(pbrInputs);
	float D = microfacetDistribution(pbrInputs);


    // Calculation of analytical lighting contribution
	vec3 diffuseContrib = (1.0 - F) * diffuse(pbrInputs);
	vec3 specContrib = F * G * D / (4.0 * NdotL * NdotV);
	// Obtain final intensity as reflectance (BRDF) scaled by the energy of the light (cosine law)
	vec3 color = NdotL * (diffuseContrib + specContrib);

	// Calculate lighting contribution from image based lighting source (IBL)
	color += getIBLContribution(pbrInputs, n, reflection);

	//const float u_OcclusionStrength = 1.0f;
	// Apply optional PBR terms for additional (optional) shading
	if (u_occlusion_texture_flag > 1.0) {
		float ao = texture(s_occlusion, v_texcoord0).r;
		//color = mix(color, color * ao, u_OcclusionStrength);
        color = color * ao;
	}

	if (u_emissive_texture_flag > 1.0) {
		vec3 emissive = toLinear(texture(s_emissive, v_texcoord0)).rgb * u_emissive_factor;
		color += emissive;
	}
	
	outColor = vec4(color, baseColor.a);
}
