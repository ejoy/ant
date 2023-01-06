$input v_texcoord0
#include <bgfx_shader.sh>

#include "common/constants.sh"

// ES 3.0/3.1 gives us the ARB_gpu_shader5 bits we need
#define gpu_shader5        1

// ES 3.0 does not have gather though
#ifdef ENABLE_TEXTURE_GATHER
#define FXAA_GATHER4_ALPHA 1
#else //ENABLE_TEXTURE_GATHER
#define FXAA_GATHER4_ALPHA 0
#endif //ENABLE_TEXTURE_GATHER

//#define FXAA_PC_CONSOLE    1
#define FXAA_PC 1
#define FXAA_GLSL_130      1

#define G3D_FXAA_PATCHES   1

#ifndef COMPUTE_LUMINANCE_TO_ALPHA
#define FXAA_GREEN_AS_LUMA 1
#endif //!COMPUTE_LUMINANCE_TO_ALPHA

#include "postprocess/fxaa/fxaa.sh"

SAMPLER2D(s_scene_ldr_color,  0);

void main()
{
#if FXAA_PC
    gl_FragColor = FxaaPixelShader(
        v_texcoord0,
        s_scene_ldr_color,
        u_viewTexel.xy,
        0.75,                                   //FxaaFloat fxaaQualitySubpix
        0.125,                                  //FxaaFloat fxaaQualityEdgeThreshold
        0.0833                                  //FxaaFloat fxaaQualityEdgeThresholdMin
    );
#else   //!FXAA_PC
    //we assume v_texcoord0 is in texel center
    const vec2 half_texel = u_viewTexel.xy * 0.5;
    vec2 max_corner = v_texcoord0 + half_texel;
    vec2 min_Corner = v_texcoord0 - half_texel;
    gl_FragColor = FxaaPixelShader(
            v_texcoord0,
            vec4(min_Corner, max_corner),
            s_scene_ldr_color,
            u_viewTexel.xy,                     // FxaaFloat4 fxaaConsoleRcpFrameOpt,
            2.0 * u_viewTexel.xy,               // FxaaFloat4 fxaaConsoleRcpFrameOpt2,
            8.0,                                // FxaaFloat fxaaConsoleEdgeSharpness,
#if defined(G3D_FXAA_PATCHES) && G3D_FXAA_PATCHES == 1
            0.08,                               // FxaaFloat fxaaConsoleEdgeThreshold,
#else
            0.125,                              // FxaaFloat fxaaConsoleEdgeThreshold,
#endif
            0.04                                // FxaaFloat fxaaConsoleEdgeThresholdMin
    );
#endif  //FXAA_PC

}