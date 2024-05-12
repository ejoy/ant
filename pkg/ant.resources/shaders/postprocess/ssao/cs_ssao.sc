$input v_texcoord0

#include <bgfx_shader.sh>
#include <shaderlib.sh>
#include <bgfx_compute.sh>

#include "common/common.sh"
#include "common/postprocess.sh"
#include "common/camera.sh"
#include "common/utils.sh"
#include "common/math.sh"

#include "postprocess/ssao/uniforms.sh"
#include "postprocess/ssao/ssct.sh"

SAMPLER2D(s_depth, 0);

#ifdef ENABLE_BENT_NORMAL
IMAGE2D_ARRAY_WO(s_ssao_result, rgba8, 1);
#else
IMAGE2D_WO(s_ssao_result, rgba8, 1);
#endif //ENABLE_BENT_NORMAL

//code from filament ssao

const float kLog2LodRate = 3.0;

highp vec2 startPosition(const float noise) {
    float angle = (PI2 * 2.4) * noise;
    return vec2(cos(angle), sin(angle));
}

highp mat2 tapAngleStep() {
    const float c = u_ssao_angle_inc_cos;
    const float s = u_ssao_angle_inc_sin;
    // the rotation matrix in column mode
    return mat2(
         c, s,   //col0
        -s, c);  //col1
}

float tapRadius2(float i, float noise){
    return sq((i + noise + 0.5) * u_ssao_inv_sample_count);
}

vec3 tapLocationFast(float i, vec2 p, const float noise) {
    return vec3(p, tapRadius2(i, noise));
}

vec3 fetchSamplePos(float i, float ssDiskRadius, const highp vec2 uv, const vec2 tapPosition, const float noise)
{
    //vec3 tap = tapLocationFast(i, tapPosition, noise);
    const float r2 = tapRadius2(i, noise);

    float ssRadius = max(1.0, r2 * ssDiskRadius); // at least 1 pixel screen-space radius
    vec2 uvSamplePos = uv + vec2(ssRadius * tapPosition) * u_ssao_texelsize.xy;

    float level = clamp(floor(log2(ssRadius)) - kLog2LodRate, 0.0, u_ssao_max_level);

    return vec3(uvSamplePos, level);
}

void computeAmbientOcclusionSAO(inout float occlusion, inout vec3 bentNormal,
        const highp vec3 origin, const vec3 normal, const vec3 samplePos) {
    highp float occlusionDepth = depthVS_from_texture(s_depth, samplePos.xy, samplePos.z);
    highp vec3 p = posVS_from_depth(samplePos.xy, occlusionDepth);//computeViewSpacePositionFromDepth(uvSamplePos, occlusionDepth, materialParams.positionParams);

    // now we have the sample, compute AO
    highp vec3 v = p - origin;  // sample vector
    float vv = dot(v, v);       // squared distance
    float vn = dot(v, normal);  // distance * cos(v, normal)

    // discard samples that are outside of the radius, preventing distant geometry to
    // cast shadows -- there are many functions that work and choosing one is an artistic
    // decision.
    float w = sq(max(0.0, 1.0 - vv * u_ssao_inv_radius_squared));

    // discard samples that are too close to the horizon to reduce shadows cast by geometry
    // not sufficently tessellated. The goal is to discard samples that form an angle 'beta'
    // smaller than 'epsilon' with the horizon. We already have dot(v,n) which is equal to the
    // sin(beta) * |v|. So the test simplifies to vn^2 < vv * sin(epsilon)^2.
    w *= step(vv * u_ssao_min_horizon_angle_sine_squared, vn * vn);

    float sampleOcclusion = max(0.0, vn - (origin.z * u_ssao_bias)) / (vv + u_ssao_peak2);
    occlusion += w * sampleOcclusion;

#if ENABLE_BENT_NORMAL

    // TODO: revisit how we choose to keep the normal or not
    // reject samples beyond the far plane
    if (occlusionDepth * u_inv_far < 1.0) {
        float rr = 1.0 / u_ssao_inv_radius_squared;
        float cc = vv - vn*vn;
        float s = sqrt(max(0.0, rr - cc));
        vec3 n = normalize(v + normal * (s - vn));// vn is negative
        bentNormal += n * (sampleOcclusion <= 0.0 ? 1.0 : 0.0);
    }

#endif //ENABLE_BENT_NORMAL
}

void scalableAmbientObscurance(out float obscurance, out vec3 bentNormal,
        highp vec2 uv, highp vec3 origin, highp float noise, highp vec3 normal) {
    highp vec2 tapPosition = startPosition(noise);
    highp mat2 angleStep = tapAngleStep();

    // Choose the screen-space sample radius
    // proportional to the projected area of the sphere
    float ssDiskRadius = (u_ssao_projection_scale_radius / origin.z);

    obscurance = 0.0;
    bentNormal = normal;
    for (float i = 0.0; i < u_ssao_sample_count; i += 1.0) {
        const vec3 samplePos = fetchSamplePos(i, ssDiskRadius, uv, tapPosition, noise);
        computeAmbientOcclusionSAO(obscurance, bentNormal, origin, normal, samplePos);
        tapPosition = mul(angleStep, tapPosition);
    }
    obscurance = sqrt(obscurance * u_ssao_intensity);
#if ENABLE_BENT_NORMAL
    bentNormal = normalize(bentNormal);
#endif //ENABLE_BENT_NORMAL
}

ConeTraceSetup init_cone_trace(highp vec2 uv, highp vec3 origin, vec3 normal)
{
    ConeTraceSetup cone;

    vec4 resolution = fetch_texture2d_size(s_depth, 0);
    cone.ssStartPos = uv * resolution.zw;                           //materialParams.resolution.xy;
    cone.vsStartPos = origin;
    cone.vsNormal   = normal;

    cone.vsConeDirection        = u_ssct_lightdirVS;                //materialParams.ssctVsLightDirection;
    cone.shadowDistance         = u_ssct_shadow_distance;           //materialParams.ssctShadowDistance;
    cone.coneAngleTangeant      = u_ssct_cone_angle_tangeant;       //materialParams.ssctConeAngleTangeant;
    cone.contactDistanceMaxInv  = u_ssct_contact_distance_max_inv;  //materialParams.ssctContactDistanceMaxInv;

    cone.screenFromViewMatrix   = u_ssct_screen_from_view_mat;      //materialParams.screenFromViewMatrix;
    cone.projectionScale        = u_ssct_projection_scale;          //materialParams.projectionScale;
    
    cone.resolution             = resolution;//materialParams.resolution;
    cone.maxLevel               = u_ssao_max_level;//float(materialParams.maxLevel);

    cone.intensity              = u_ssct_intensity;//materialParams.ssctIntensity;
    cone.depthBias              = u_ssct_depth_bias;
    cone.slopeScaledDepthBias   = u_ssct_slope_scaled_depth_bias;
    cone.sampleCount            = u_ssct_sample_count;//u_ssao_sample_count; //materialParams.ssctSampleCount;
    return cone;
}

float dominantLightShadowing(highp vec2 uv, highp vec3 origin, vec3 normal, vec2 fragcoord) {
    ConeTraceSetup cone = init_cone_trace(uv, origin, normal);
    return ssctDominantLightShadowing(uv, origin, normal,
            s_depth, fragcoord, //getFragCoord(cone.xy),
            u_ssct_ray_count, cone);
}

NUM_THREADS(16, 16, 1)
void main()
{
    const ivec2 uv_out = gl_GlobalInvocationID.xy;

#ifdef ENABLE_BENT_NORMAL
    const ivec2 size = imageSize(s_ssao_result).xy;
#else //!ENABLE_BENT_NORMAL
    const ivec2 size = imageSize(s_ssao_result);
#endif //ENABLE_BENT_NORMAL
    if (any(uv_out >= size))
        return;

    const vec2 uv = id2uv(uv_out, size);
    highp float depth_non_linear = texture2DLod(s_depth, uv, 0.0).r;
    highp float depthVS = linear_depth_pp(depth_non_linear);//depthVS_from_texture(s_depth, uv, 0.0);

    highp vec3 origin = posVS_from_depth(uv, depthVS);
#ifdef HIGH_QULITY_NORMAL_RECONSTRUCT
    highp vec3 normal = normalVS_from_depth_HighQ(s_depth, uv, depth_non_linear, origin, u_ssao_texelsize);
#else //!HIGH_QULITY_NORMAL_RECONSTRUCT
    highp vec3 normal = normalVS_from_depth(s_depth, uv, origin, u_ssao_texelsize);
#endif //HIGH_QULITY_NORMAL_RECONSTRUCT
    highp float occlusion = 0.0;
    highp vec3 bentNormal;

    if (u_ssao_intensity > 0.0) {
        highp float noise = interleavedGradientNoise(uv_out.xy+0.5);
        scalableAmbientObscurance(occlusion, bentNormal, uv, origin, noise, normal);
    }

    if (u_ssct_intensity > 0.0) {
        occlusion += max(occlusion, dominantLightShadowing(uv, origin, normal, uv_out));
    }

    // occlusion to visibility
    highp float aoVisibility = pow(saturate(1.0 - occlusion), u_ssao_visiblity_power);

// #if defined(TARGET_MOBILE)
//     // this line is needed to workaround what seems to be a bug on qualcomm hardware
//     aoVisibility += gl_FragCoord.x * MEDIUMP_FLT_MIN;
// #endif

#ifdef ENABLE_BENT_NORMAL
    imageStore(s_ssao_result, ivec3(uv_out, 0), vec4(vec3(aoVisibility, packHalfFloat(origin.z * u_inv_far)), 1.0));
    imageStore(s_ssao_result, ivec3(uv_out, 1), vec4(encodeNormalUint(bentNormal), 1.0));
#else //!ENABLE_BENT_NORMAL
    imageStore(s_ssao_result, uv_out, vec4(vec3(aoVisibility, packHalfFloat(origin.z * u_inv_far)), 1.0));
#endif //ENABLE_BENT_NORMAL
}