#version 310 es

#define TARGET_MOBILE
#extension GL_GOOGLE_cpp_style_line_directive : enable

#define TARGET_GLES_ENVIRONMENT

#define FILAMENT_VULKAN_SEMANTICS

precision mediump float;
precision mediump int;
precision lowp sampler2DArray;
precision lowp sampler3D;
#if defined(GL_GOOGLE_cpp_style_line_directive)
#line 0 "common_types.fs"
#endif
#if defined(FILAMENT_VULKAN_SEMANTICS)
#define LAYOUT_LOCATION(x) layout(location = x)
#else
#define LAYOUT_LOCATION(x)
#endif

#define bool2    bvec2
#define bool3    bvec3
#define bool4    bvec4

#define int2     ivec2
#define int3     ivec3
#define int4     ivec4

#define uint2    uvec2
#define uint3    uvec3
#define uint4    uvec4

#define float2   vec2
#define float3   vec3
#define float4   vec4

#define float3x3 mat3
#define float4x4 mat4

// Adreno drivers seem to ignore precision qualifiers in structs, unless they're used in
// UBOs, which is is the case here.
struct ShadowData {
    highp mat4 lightFromWorldMatrix;
    highp vec3 direction;
    float normalBias;
    highp vec4 lightFromWorldZ;
    float texelSizeAtOneMeter;
    float bulbRadiusLs;
    float nearOverFarMinusNear;
};

struct BoneData {
    highp mat3x4 transform;    // bone transform is mat4x3 stored in row-major (last row [0,0,0,1])
    highp uvec4 cof;           // 8 first cofactor matrix of transform's upper left
};

struct PerRenderableData {
    highp mat4 worldFromModelMatrix;
    highp mat3 worldFromModelNormalMatrix;
    highp uint morphTargetCount;
    highp uint flagsChannels;                   // see packFlags() below (0x00000fll)
    highp uint objectId;                        // used for picking
    highp float userData;   // TODO: We need a better solution, this currently holds the average local scale for the renderable
    highp vec4 reserved[8];
};

#define FILAMENT_QUALITY_LOW    0
#define FILAMENT_QUALITY_NORMAL 1
#define FILAMENT_QUALITY_HIGH   2
#define FILAMENT_QUALITY FILAMENT_QUALITY_LOW
#define GEOMETRIC_SPECULAR_AA
#define MAX_SHADOW_CASTING_SPOTS 14
#define SPECULAR_AMBIENT_OCCLUSION 1
#define MATERIAL_HAS_REFLECTIONS
#define MULTI_BOUNCE_AMBIENT_OCCLUSION 0
#define MATERIAL_HAS_INSTANCES
#define MATERIAL_HAS_DOUBLE_SIDED_CAPABILITY
#define BLEND_MODE_OPAQUE
#define POST_LIGHTING_BLEND_MODE_TRANSPARENT
#define SHADING_MODEL_LIT
#define MATERIAL_HAS_BASE_COLOR
#define MATERIAL_HAS_ROUGHNESS
#define MATERIAL_HAS_METALLIC
#define MATERIAL_HAS_REFLECTANCE
#define MATERIAL_HAS_AMBIENT_OCCLUSION
#define MATERIAL_HAS_CLEAR_COAT
#define MATERIAL_HAS_CLEAR_COAT_ROUGHNESS
#define MATERIAL_HAS_CLEAR_COAT_NORMAL
#define MATERIAL_HAS_ANISOTROPY
#define MATERIAL_HAS_ANISOTROPY_DIRECTION
#define MATERIAL_HAS_THICKNESS
#define MATERIAL_HAS_SUBSURFACE_POWER
#define MATERIAL_HAS_SUBSURFACE_COLOR
#define MATERIAL_HAS_SHEEN_COLOR
#define MATERIAL_HAS_SHEEN_ROUGHNESS
#define MATERIAL_HAS_SPECULAR_COLOR
#define MATERIAL_HAS_GLOSSINESS
#define MATERIAL_HAS_EMISSIVE
#define MATERIAL_HAS_NORMAL
#define MATERIAL_HAS_POST_LIGHTING_COLOR
#define MATERIAL_HAS_CLIP_SPACE_TRANSFORM
#define MATERIAL_HAS_ABSORPTION
#define MATERIAL_HAS_TRANSMISSION
#define MATERIAL_HAS_IOR
#define MATERIAL_HAS_MICRO_THICKNESS
#define MATERIAL_HAS_BENT_NORMAL
#define MATERIAL_NEEDS_TBN
#define SHADING_INTERPOLATION 
#define HAS_ATTRIBUTE_TANGENTS
#define HAS_ATTRIBUTE_UV0
#define VARYING in
#if defined(GL_GOOGLE_cpp_style_line_directive)
#line 0 "varyings.glsl"
#endif
//------------------------------------------------------------------------------
// Varyings
//------------------------------------------------------------------------------

LAYOUT_LOCATION(4) VARYING highp vec4 vertex_worldPosition;

#if defined(HAS_ATTRIBUTE_TANGENTS)
LAYOUT_LOCATION(5) SHADING_INTERPOLATION VARYING mediump vec3 vertex_worldNormal;
#if defined(MATERIAL_NEEDS_TBN)
LAYOUT_LOCATION(6) SHADING_INTERPOLATION VARYING mediump vec4 vertex_worldTangent;
#endif
#endif

LAYOUT_LOCATION(7) VARYING highp vec4 vertex_position;

LAYOUT_LOCATION(8) flat VARYING highp int instance_index;

#if defined(HAS_ATTRIBUTE_COLOR)
LAYOUT_LOCATION(9) VARYING mediump vec4 vertex_color;
#endif

#if defined(HAS_ATTRIBUTE_UV0) && !defined(HAS_ATTRIBUTE_UV1)
LAYOUT_LOCATION(10) VARYING highp vec2 vertex_uv01;
#elif defined(HAS_ATTRIBUTE_UV1)
LAYOUT_LOCATION(10) VARYING highp vec4 vertex_uv01;
#endif

#if defined(VARIANT_HAS_SHADOWING) && defined(VARIANT_HAS_DIRECTIONAL_LIGHTING)
LAYOUT_LOCATION(11) VARYING highp vec4 vertex_lightSpacePosition;
#endif

// Note that fragColor is an output and is not declared here; see main.fs and depth_main.fs

layout(binding = 0, std140) uniform FrameUniforms {
    highp mat4 viewFromWorldMatrix;
    highp mat4 worldFromViewMatrix;
    highp mat4 clipFromViewMatrix;
    highp mat4 viewFromClipMatrix;
    highp mat4 clipFromWorldMatrix;
    highp mat4 worldFromClipMatrix;
    vec2 clipControl;
    highp float time;
    highp float temporalNoise;
    highp vec4 userTime;
    highp vec2 origin;
    highp vec2 offset;
    highp vec4 resolution;
    float lodBias;
    float refractionLodOffset;
    float padding1;
    float padding2;
    highp vec3 cameraPosition;
    highp float oneOverFarMinusNear;
    vec3 worldOffset;
    highp float nearOverFarMinusNear;
    float cameraFar;
    highp float exposure;
    float ev100;
    float needsAlphaChannel;
    float aoSamplingQualityAndEdgeDistance;
    float aoBentNormals;
    float aoReserved0;
    float aoReserved1;
    vec4 zParams;
    uvec3 fParams;
    uint lightChannels;
    vec2 froxelCountXY;
    float iblLuminance;
    float iblRoughnessOneLevel;
    vec3 iblSH[9];
    vec3 lightDirection;
    float padding0;
    vec4 lightColorIntensity;
    vec4 sun;
    vec2 lightFarAttenuationParams;
    uint directionalShadows;
    float ssContactShadowDistance;
    highp vec4 cascadeSplits;
    uint cascades;
    float shadowBulbRadiusLs;
    float shadowBias;
    float shadowPenumbraRatioScale;
    highp mat4 lightFromWorldMatrix[4];
    float vsmExponent;
    float vsmDepthScale;
    float vsmLightBleedReduction;
    uint shadowSamplingType;
    float fogStart;
    float fogMaxOpacity;
    float fogHeight;
    float fogHeightFalloff;
    vec3 fogColor;
    float fogDensity;
    float fogInscatteringStart;
    float fogInscatteringSize;
    float fogColorFromIbl;
    float fogReserved0;
    highp mat4 ssrReprojection;
    highp mat4 ssrUvFromViewMatrix;
    float ssrThickness;
    float ssrBias;
    float ssrDistance;
    float ssrStride;
    vec4 reserved[48];
} frameUniforms;

layout(binding = 1, std140) uniform ObjectUniforms {
    PerRenderableData data[1];
} objectUniforms;

layout(binding = 4, std140) uniform LightsUniforms {
    highp mat4 lights[256];
} lightsUniforms;

layout(binding = 6, std140) uniform FroxelRecordUniforms {
    highp uvec4 records[1024];
} froxelRecordUniforms;

layout(binding = 7, std140) uniform MaterialParams {
    vec4 baseColorFactor;
    float metallicFactor;
    float roughnessFactor;
    float normalScale;
    float aoStrength;
    vec3 emissiveFactor;
    float emissiveStrength;
    float _specularAntiAliasingVariance;
    float _specularAntiAliasingThreshold;
    bool _doubleSided;
} materialParams;

layout(binding = 0) uniform mediump sampler2DArrayShadow light_shadowMap;
layout(binding = 1) uniform mediump usampler2D light_froxels;
layout(binding = 2) uniform mediump sampler2D light_iblDFG;
layout(binding = 3) uniform mediump samplerCube light_iblSpecular;
layout(binding = 4) uniform mediump sampler2DArray light_ssao;
layout(binding = 5) uniform mediump sampler2DArray light_ssr;
layout(binding = 6) uniform highp sampler2D light_structure;

layout(binding = 9) uniform  sampler2D materialParams_baseColorMap;
layout(binding = 10) uniform  sampler2D materialParams_metallicRoughnessMap;
layout(binding = 11) uniform  sampler2D materialParams_normalMap;

float filament_lodBias;

#include "common_math.glsl"
#include "common_shadowing.glsl"
#include "common_shading.fs"
#include "common_graphics.fs"
#include "common_getters.glsl"
#include "getter.fs"

#include "material_inputs.fs"

#include "shading_parameters.fs"
#include "fog.fs"

void material(inout MaterialInputs material) {
    highp float2 normalUV = getUV0();

    material.normal = texture(materialParams_normalMap, normalUV).xyz * 2.0 - 1.0;
    material.normal.xy *= materialParams.normalScale;

    prepareMaterial(material);
    material.baseColor = materialParams.baseColorFactor;
    highp float2 baseColorUV = getUV0();

    material.baseColor *= texture(materialParams_baseColorMap, baseColorUV);

    material.roughness = materialParams.roughnessFactor;
    material.metallic = materialParams.metallicFactor;
    material.emissive = vec4(materialParams.emissiveStrength *
    materialParams.emissiveFactor.rgb, 0.0);
    highp float2 metallicRoughnessUV = getUV0();

    vec4 mr = texture(materialParams_metallicRoughnessMap, metallicRoughnessUV);
    material.roughness *= mr.g;
    material.metallic *= mr.b;
}

#include "common_lighting.fs"
#include "brdf.fs"

#include "ambient_occlusion.fs"
#include "light_directional.fs"
#include "light_indirect.fs"
#include "shading_lit.fs"

layout(location = 0) out vec4 fragColor;

#if defined(MATERIAL_HAS_POST_LIGHTING_COLOR)
void blendPostLightingColor(const MaterialInputs material, inout vec4 color) {
#if defined(POST_LIGHTING_BLEND_MODE_OPAQUE)
    color = material.postLightingColor;
#elif defined(POST_LIGHTING_BLEND_MODE_TRANSPARENT)
    color = material.postLightingColor + color * (1.0 - material.postLightingColor.a);
#elif defined(POST_LIGHTING_BLEND_MODE_ADD)
    color += material.postLightingColor;
#elif defined(POST_LIGHTING_BLEND_MODE_MULTIPLY)
    color *= material.postLightingColor;
#elif defined(POST_LIGHTING_BLEND_MODE_SCREEN)
    color += material.postLightingColor * (1.0 - color);
#endif
}
#endif

void main() {
    filament_lodBias = frameUniforms.lodBias;

    // See shading_parameters.fs
    // Computes global variables we need to evaluate material and lighting
    computeShadingParams();

    // Initialize the inputs to sensible default values, see material_inputs.fs
    MaterialInputs inputs;
    initMaterial(inputs);

    // Invoke user code
    material(inputs);

    fragColor = evaluateMaterial(inputs);

#if defined(VARIANT_HAS_DIRECTIONAL_LIGHTING) && defined(VARIANT_HAS_SHADOWING)
    bool visualizeCascades = bool(frameUniforms.cascades & 0x10u);
    if (visualizeCascades) {
        fragColor.rgb *= uintToColorDebug(getShadowCascade());
    }
#endif

#if defined(VARIANT_HAS_FOG)
    vec3 view = getWorldPosition() - getWorldCameraPosition();
    fragColor = fog(fragColor, view);
#endif

#if defined(MATERIAL_HAS_POST_LIGHTING_COLOR) && !defined(MATERIAL_HAS_REFLECTIONS)
    blendPostLightingColor(inputs, fragColor);
#endif
}

