/**
  G3D version of FXAA. See copyright and warranty statement below.

  G3D Innovation Engine http://casual-effects.com/g3d
  Copyright 2000-2018, Morgan McGuire
  All rights reserved
  Available under the BSD License
*/

/*============================================================================


                    NVIDIA FXAA 3.11 by TIMOTHY LOTTES
               (modified for G3D with bug fixes and PC GLSL preamble)

------------------------------------------------------------------------------
COPYRIGHT (C) 2010, 2011 NVIDIA CORPORATION. ALL RIGHTS RESERVED.
------------------------------------------------------------------------------
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THIS SOFTWARE IS PROVIDED
*AS IS* AND NVIDIA AND ITS SUPPLIERS DISCLAIM ALL WARRANTIES, EITHER EXPRESS
OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL NVIDIA
OR ITS SUPPLIERS BE LIABLE FOR ANY SPECIAL, INCIDENTAL, INDIRECT, OR
CONSEQUENTIAL DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR
LOSS OF BUSINESS PROFITS, BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION,
OR ANY OTHER PECUNIARY LOSS) ARISING OUT OF THE USE OF OR INABILITY TO USE
THIS SOFTWARE, EVEN IF NVIDIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
DAMAGES.

------------------------------------------------------------------------------
                           INTEGRATION CHECKLIST
------------------------------------------------------------------------------
(1.)
In the shader source, setup defines for the desired configuration.
When providing multiple shaders (for different presets),
simply setup the defines differently in multiple files.
Example,

  #define FXAA_PC 1
  #define FXAA_HLSL_5 1
  #define FXAA_QUALITY_PRESET 12

Or,

  #define FXAA_360 1
  
Or,

  #define FXAA_PS3 1
  
Etc.

(2.)
Then include this file,

  include "Fxaa3_11.h"

(3.)
Then call the FXAA pixel shader from within your desired shader.
Look at the FXAA Quality FxaaPixelShader() for docs on inputs.
As for FXAA 3.11 all inputs for all shaders are the same 
to enable easy porting between platforms.

  return FxaaPixelShader(...);

(4.)
Insure pass prior to FXAA outputs RGBL (see next section).
Or use,

  #define FXAA_GREEN_AS_LUMA 1

(5.)
Setup engine to provide the following constants
which are used in the FxaaPixelShader() inputs,

  FxaaFloat2 fxaaQualityRcpFrame,
  FxaaFloat4 fxaaConsoleRcpFrameOpt,
  FxaaFloat4 fxaaConsoleRcpFrameOpt2,
  FxaaFloat fxaaQualitySubpix,
  FxaaFloat fxaaQualityEdgeThreshold,
  FxaaFloat fxaaQualityEdgeThresholdMin,
  FxaaFloat fxaaConsoleEdgeSharpness,
  FxaaFloat fxaaConsoleEdgeThreshold,
  FxaaFloat fxaaConsoleEdgeThresholdMin

Look at the FXAA Quality FxaaPixelShader() for docs on inputs.

(6.)
Have FXAA vertex shader run as a full screen triangle,
and output "pos" and "fxaaConsolePosPos" 
such that inputs in the pixel shader provide,

  // {xy} = center of pixel
  FxaaFloat2 pos,

  // {xy__} = upper left of pixel
  // {__zw} = lower right of pixel
  FxaaFloat4 fxaaConsolePosPos,

(7.)
Insure the texture sampler(s) used by FXAA are set to bilinear filtering.


------------------------------------------------------------------------------
                    INTEGRATION - RGBL AND COLORSPACE
------------------------------------------------------------------------------
FXAA3 requires RGBL as input unless the following is set, 

  #define FXAA_GREEN_AS_LUMA 1

In which case the engine uses green in place of luma,
and requires RGB input is in a non-linear colorspace.

RGB should be LDR (low dynamic range).
Specifically do FXAA after tonemapping.

RGB data as returned by a texture fetch can be non-linear,
or linear when FXAA_GREEN_AS_LUMA is not set.
Note an "sRGB format" texture counts as linear,
because the result of a texture fetch is linear data.
Regular "RGBA8" textures in the sRGB colorspace are non-linear.

If FXAA_GREEN_AS_LUMA is not set,
luma must be stored in the alpha channel prior to running FXAA.
This luma should be in a perceptual space (could be gamma 2.0).
Example pass before FXAA where output is gamma 2.0 encoded,

  color.rgb = ToneMap(color.rgb); // linear color output
  color.rgb = sqrt(color.rgb);    // gamma 2.0 color output
  return color;

To use FXAA,

  color.rgb = ToneMap(color.rgb);  // linear color output
  color.rgb = sqrt(color.rgb);     // gamma 2.0 color output
  color.a = dot(color.rgb, FxaaFloat3(0.299, 0.587, 0.114)); // compute luma
  return color;

Another example where output is linear encoded,
say for instance writing to an sRGB formated render target,
where the render target does the conversion back to sRGB after blending,

  color.rgb = ToneMap(color.rgb); // linear color output
  return color;

To use FXAA,

  color.rgb = ToneMap(color.rgb); // linear color output
  color.a = sqrt(dot(color.rgb, FxaaFloat3(0.299, 0.587, 0.114))); // compute luma
  return color;

Getting luma correct is required for the algorithm to work correctly.


------------------------------------------------------------------------------
                          BEING LINEARLY CORRECT?
------------------------------------------------------------------------------
Applying FXAA to a framebuffer with linear RGB color will look worse.
This is very counter intuitive, but happends to be true in this case.
The reason is because dithering artifacts will be more visible 
in a linear colorspace.


------------------------------------------------------------------------------
                             COMPLEX INTEGRATION
------------------------------------------------------------------------------
Q. What if the engine is blending into RGB before wanting to run FXAA?

A. In the last opaque pass prior to FXAA,
   have the pass write out luma into alpha.
   Then blend into RGB only.
   FXAA should be able to run ok
   assuming the blending pass did not any add aliasing.
   This should be the common case for particles and common blending passes.

A. Or use FXAA_GREEN_AS_LUMA.

============================================================================*/

/*============================================================================

                             INTEGRATION KNOBS

============================================================================*/
/*==========================================================================*/
#ifndef FXAA_PC
    //
    // FXAA Quality
    // The high quality PC algorithm.
    //
    #define FXAA_PC 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_PC_CONSOLE
    //
    // The console algorithm for PC is included
    // for developers targeting really low spec machines.
    // Likely better to just run FXAA_PC, and use a really low preset.
    //
    #define FXAA_PC_CONSOLE 0
#endif

#ifndef G3D_FXAA_PATCHES
#   define G3D_FXAA_PATCHES 0
#endif

/*--------------------------------------------------------------------------*/
#ifndef FXAA_GLSL_120
    #define FXAA_GLSL_120 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_GLSL_130
    #define FXAA_GLSL_130 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_HLSL_3
    #define FXAA_HLSL_3 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_HLSL_4
    #define FXAA_HLSL_4 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_HLSL_5
    #define FXAA_HLSL_5 0
#endif
/*--------------------------------------------------------------------------*/
/*==========================================================================*/
#ifndef FXAA_GREEN_AS_LUMA
    //
    // For those using non-linear color,
    // and either not able to get luma in alpha, or not wanting to,
    // this enables FXAA to run using green as a proxy for luma.
    // So with this enabled, no need to pack luma in alpha.
    //
    // This will turn off AA on anything which lacks some amount of green.
    // Pure red and blue or combination of only R and B, will get no AA.
    //
    // Might want to lower the settings for both,
    //    fxaaConsoleEdgeThresholdMin
    //    fxaaQualityEdgeThresholdMin
    // In order to insure AA does not get turned off on colors 
    // which contain a minor amount of green.
    //
    // 1 = On.
    // 0 = Off.
    //
    #define FXAA_GREEN_AS_LUMA 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_EARLY_EXIT
    //
    // Controls algorithm's early exit path.
    // On PS3 turning this ON adds 2 cycles to the shader.
    // On 360 turning this OFF adds 10ths of a millisecond to the shader.
    // Turning this off on console will result in a more blurry image.
    // So this defaults to on.
    //
    // 1 = On.
    // 0 = Off.
    //
    #define FXAA_EARLY_EXIT 1
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_DISCARD
    //
    // Only valid for PC OpenGL currently.
    // Probably will not work when FXAA_GREEN_AS_LUMA = 1.
    //
    // 1 = Use discard on pixels which don't need AA.
    //     For APIs which enable concurrent TEX+ROP from same surface.
    // 0 = Return unchanged color on pixels which don't need AA.
    //
    #define FXAA_DISCARD 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_FAST_PIXEL_OFFSET
    //
    // Used for GLSL 120 only.
    //
    // 1 = GL API supports fast pixel offsets
    // 0 = do not use fast pixel offsets
    //
    #ifdef GL_EXT_gpu_shader4
        #define FXAA_FAST_PIXEL_OFFSET 1
    #endif
    #ifdef GL_NV_gpu_shader5
        #define FXAA_FAST_PIXEL_OFFSET 1
    #endif
    #ifdef gpu_shader5
        #define FXAA_FAST_PIXEL_OFFSET 1
    #endif
    #ifndef FXAA_FAST_PIXEL_OFFSET
        #define FXAA_FAST_PIXEL_OFFSET 0
    #endif
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_GATHER4_ALPHA
    //
    // 1 = API supports gather4 on alpha channel.
    // 0 = API does not support gather4 on alpha channel.
    //
    #if (FXAA_HLSL_5 == 1)
        #define FXAA_GATHER4_ALPHA 1
    #endif
    #ifdef gpu_shader5
        #define FXAA_GATHER4_ALPHA 1
    #endif
    #ifdef GL_NV_gpu_shader5
        #define FXAA_GATHER4_ALPHA 1
    #endif
    #ifndef FXAA_GATHER4_ALPHA
        #define FXAA_GATHER4_ALPHA 0
    #endif
#endif

/*============================================================================
                        FXAA QUALITY - TUNING KNOBS
------------------------------------------------------------------------------
NOTE the other tuning knobs are now in the shader function inputs!
============================================================================*/
#ifndef FXAA_QUALITY_PRESET
    //
    // Choose the quality preset.
    // This needs to be compiled into the shader as it affects code.
    // Best option to include multiple presets is to 
    // in each shader define the preset, then include this file.
    // 
    // OPTIONS
    // -----------------------------------------------------------------------
    // 10 to 15 - default medium dither (10=fastest, 15=highest quality)
    // 20 to 29 - less dither, more expensive (20=fastest, 29=highest quality)
    // 39       - no dither, very expensive 
    //
    // NOTES
    // -----------------------------------------------------------------------
    // 12 = slightly faster then FXAA 3.9 and higher edge quality (default)
    // 13 = about same speed as FXAA 3.9 and better than 12
    // 23 = closest to FXAA 3.9 visually and performance wise
    //  _ = the lowest digit is directly related to performance
    // _  = the highest digit is directly related to style
    // 
    #define FXAA_QUALITY_PRESET 12
#endif


/*============================================================================

                           FXAA QUALITY - PRESETS

============================================================================*/

/*============================================================================
                     FXAA QUALITY - MEDIUM DITHER PRESETS
============================================================================*/
#if (FXAA_QUALITY_PRESET == 10)
    #define FXAA_QUALITY__PS 3
    #define FXAA_QUALITY__P0 1.5
    #define FXAA_QUALITY__P1 3.0
    #define FXAA_QUALITY__P2 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 11)
    #define FXAA_QUALITY__PS 4
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 3.0
    #define FXAA_QUALITY__P3 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 12)
    #define FXAA_QUALITY__PS 5
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 4.0
    #define FXAA_QUALITY__P4 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 13)
    #define FXAA_QUALITY__PS 6
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 4.0
    #define FXAA_QUALITY__P5 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 14)
    #define FXAA_QUALITY__PS 7
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 4.0
    #define FXAA_QUALITY__P6 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 15)
    #define FXAA_QUALITY__PS 8
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 4.0
    #define FXAA_QUALITY__P7 12.0
#endif

/*============================================================================
                     FXAA QUALITY - LOW DITHER PRESETS
============================================================================*/
#if (FXAA_QUALITY_PRESET == 20)
    #define FXAA_QUALITY__PS 3
    #define FXAA_QUALITY__P0 1.5
    #define FXAA_QUALITY__P1 2.0
    #define FXAA_QUALITY__P2 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 21)
    #define FXAA_QUALITY__PS 4
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 22)
    #define FXAA_QUALITY__PS 5
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 23)
    #define FXAA_QUALITY__PS 6
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 24)
    #define FXAA_QUALITY__PS 7
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 3.0
    #define FXAA_QUALITY__P6 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 25)
    #define FXAA_QUALITY__PS 8
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 4.0
    #define FXAA_QUALITY__P7 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 26)
    #define FXAA_QUALITY__PS 9
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 4.0
    #define FXAA_QUALITY__P8 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 27)
    #define FXAA_QUALITY__PS 10
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 2.0
    #define FXAA_QUALITY__P8 4.0
    #define FXAA_QUALITY__P9 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 28)
    #define FXAA_QUALITY__PS 11
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 2.0
    #define FXAA_QUALITY__P8 2.0
    #define FXAA_QUALITY__P9 4.0
    #define FXAA_QUALITY__P10 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY_PRESET == 29)
    #define FXAA_QUALITY__PS 12
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 2.0
    #define FXAA_QUALITY__P8 2.0
    #define FXAA_QUALITY__P9 2.0
    #define FXAA_QUALITY__P10 4.0
    #define FXAA_QUALITY__P11 8.0
#endif

/*============================================================================
                     FXAA QUALITY - EXTREME QUALITY
============================================================================*/
#if (FXAA_QUALITY_PRESET == 39)
    #define FXAA_QUALITY__PS 12
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.0
    #define FXAA_QUALITY__P2 1.0
    #define FXAA_QUALITY__P3 1.0
    #define FXAA_QUALITY__P4 1.0
    #define FXAA_QUALITY__P5 1.5
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 2.0
    #define FXAA_QUALITY__P8 2.0
    #define FXAA_QUALITY__P9 2.0
    #define FXAA_QUALITY__P10 4.0
    #define FXAA_QUALITY__P11 8.0
#endif

/*============================================================================

                                API PORTING

============================================================================*/
#if (FXAA_GLSL_120 == 1) || (FXAA_GLSL_130 == 1)
    #define FxaaBool bool
    #define FxaaDiscard discard
    #define FxaaFloat float
    #define FxaaFloat2 vec2
    #define FxaaFloat3 vec3
    #define FxaaFloat4 vec4
    #define FxaaHalf float
    #define FxaaHalf2 vec2
    #define FxaaHalf3 vec3
    #define FxaaHalf4 vec4
    #define FxaaInt2 ivec2
    #define FxaaSat(x) clamp(x, 0.0, 1.0)
    #define FxaaTex sampler2D
#else
    #define FxaaBool bool
    #define FxaaDiscard clip(-1)
    #define FxaaFloat float
    #define FxaaFloat2 float2
    #define FxaaFloat3 float3
    #define FxaaFloat4 float4
    #define FxaaHalf half
    #define FxaaHalf2 half2
    #define FxaaHalf3 half3
    #define FxaaHalf4 half4
    #define FxaaSat(x) saturate(x)
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_GLSL_120 == 1)
    // Requires,
    //  #version 120
    // And at least,
    //  #extension GL_EXT_gpu_shader4 : enable
    //  (or set FXAA_FAST_PIXEL_OFFSET 1 to work like DX9)
    #define FxaaTexTop(t, p) texture2DLod(t, p, 0.0)
    #if (FXAA_FAST_PIXEL_OFFSET == 1)
        #define FxaaTexOff(t, p, o, r) texture2DLodOffset(t, p, 0.0, o)
    #else
        #define FxaaTexOff(t, p, o, r) texture2DLod(t, p + (o * r), 0.0)
    #endif
    #if (FXAA_GATHER4_ALPHA == 1)
        // use #extension gpu_shader5 : enable
        #define FxaaTexAlpha4(t, p) textureGather(t, p, 3)
        #define FxaaTexOffAlpha4(t, p, o) textureGatherOffset(t, p, o, 3)
        #define FxaaTexGreen4(t, p) textureGather(t, p, 1)
        #define FxaaTexOffGreen4(t, p, o) textureGatherOffset(t, p, o, 1)
    #endif
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_GLSL_130 == 1)
    // Requires "#version 130" or better
    #define FxaaTexTop(t, p) texture2DLod(t, p, 0.0)
    #define FxaaTexOff(t, p, o, r) texture2DLodOffset(t, p, 0.0, o)
    #if (FXAA_GATHER4_ALPHA == 1)
        // use #extension gpu_shader5 : enable
        #define FxaaTexAlpha4(t, p) textureGather(t, p, 3)
        #define FxaaTexOffAlpha4(t, p, o) textureGatherOffset(t, p, o, 3)
        #define FxaaTexGreen4(t, p) textureGather(t, p, 1)
        #define FxaaTexOffGreen4(t, p, o) textureGatherOffset(t, p, o, 1)
    #endif
#endif
/*--------------------------------------------------------------------------*/


/*============================================================================
                   GREEN AS LUMA OPTION SUPPORT FUNCTION
============================================================================*/
// NOTE: Using macros instead of functions here prevents the SPIR-V optimizer
//       from unnecessarily using high precision local variables
#if (FXAA_GREEN_AS_LUMA == 0)
//    FxaaFloat FxaaLuma(FxaaFloat4 rgba) { return rgba.w; }
    #define FxaaLuma(rgba) (rgba).w
#else
//    FxaaFloat FxaaLuma(FxaaFloat4 rgba) { return rgba.y; }
    #define FxaaLuma(rgba) (rgba).y
#endif    

/*============================================================================

                             FXAA3 QUALITY - PC

============================================================================*/
#if (FXAA_PC == 1)
/*--------------------------------------------------------------------------*/
FxaaFloat4 FxaaPixelShader(
    //
    // Use noperspective interpolation here (turn off perspective interpolation).
    // {xy} = center of pixel
    FxaaFloat2 pos,
    //
    // Input color texture.
    // {rgb_} = color in linear or perceptual color space
    // if (FXAA_GREEN_AS_LUMA == 0)
    //     {___a} = luma in perceptual color space (not linear)
    FxaaTex tex,
    //
    // Only used on FXAA Quality.
    // This must be from a constant/uniform.
    // {x_} = 1.0/screenWidthInPixels
    // {_y} = 1.0/screenHeightInPixels
    FxaaFloat2 fxaaQualityRcpFrame,
    //
    // Only used on FXAA Quality.
    // This used to be the FXAA_QUALITY__SUBPIX define.
    // It is here now to allow easier tuning.
    // Choose the amount of sub-pixel aliasing removal.
    // This can effect sharpness.
    //   1.00 - upper limit (softer)
    //   0.75 - default amount of filtering
    //   0.50 - lower limit (sharper, less sub-pixel aliasing removal)
    //   0.25 - almost off
    //   0.00 - completely off
    FxaaFloat fxaaQualitySubpix,
    //
    // Only used on FXAA Quality.
    // This used to be the FXAA_QUALITY__EDGE_THRESHOLD define.
    // It is here now to allow easier tuning.
    // The minimum amount of local contrast required to apply algorithm.
    //   0.333 - too little (faster)
    //   0.250 - low quality
    //   0.166 - default
    //   0.125 - high quality 
    //   0.063 - overkill (slower)
    FxaaFloat fxaaQualityEdgeThreshold,
    //
    // Only used on FXAA Quality.
    // This used to be the FXAA_QUALITY__EDGE_THRESHOLD_MIN define.
    // It is here now to allow easier tuning.
    // Trims the algorithm from processing darks.
    //   0.0833 - upper limit (default, the start of visible unfiltered edges)
    //   0.0625 - high quality (faster)
    //   0.0312 - visible limit (slower)
    // Special notes when using FXAA_GREEN_AS_LUMA,
    //   Likely want to set this to zero.
    //   As colors that are mostly not-green
    //   will appear very dark in the green channel!
    //   Tune by looking at mostly non-green content,
    //   then start at zero and increase until aliasing is a problem.
    FxaaFloat fxaaQualityEdgeThresholdMin
) {
/*--------------------------------------------------------------------------*/
    FxaaFloat2 posM;
    posM.x = pos.x;
    posM.y = pos.y;
    #if (FXAA_GATHER4_ALPHA == 1)
        #if (FXAA_DISCARD == 0)
            FxaaFloat4 rgbyM = FxaaTexTop(tex, posM);
            #if (FXAA_GREEN_AS_LUMA == 0)
                #define lumaM rgbyM.w
            #else
                #define lumaM rgbyM.y
            #endif
        #endif
        #if (FXAA_GREEN_AS_LUMA == 0)
            FxaaFloat4 luma4A = FxaaTexAlpha4(tex, posM);
            FxaaFloat4 luma4B = FxaaTexOffAlpha4(tex, posM, FxaaInt2(-1, -1));
        #else
            FxaaFloat4 luma4A = FxaaTexGreen4(tex, posM);
            FxaaFloat4 luma4B = FxaaTexOffGreen4(tex, posM, FxaaInt2(-1, -1));
        #endif
        #if (FXAA_DISCARD == 1)
            #define lumaM luma4A.w
        #endif
        #define lumaE luma4A.z
        #define lumaS luma4A.x
        #define lumaSE luma4A.y
        #define lumaNW luma4B.w
        #define lumaN luma4B.z
        #define lumaW luma4B.x
    #else
        FxaaFloat4 rgbyM = FxaaTexTop(tex, posM);
        #if (FXAA_GREEN_AS_LUMA == 0)
            #define lumaM rgbyM.w
        #else
            #define lumaM rgbyM.y
        #endif
        FxaaFloat lumaS = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2( 0, 1), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaE = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2( 1, 0), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaN = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2( 0,-1), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaW = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2(-1, 0), fxaaQualityRcpFrame.xy));
    #endif
/*--------------------------------------------------------------------------*/
    FxaaFloat maxSM = max(lumaS, lumaM);
    FxaaFloat minSM = min(lumaS, lumaM);
    FxaaFloat maxESM = max(lumaE, maxSM);
    FxaaFloat minESM = min(lumaE, minSM);
    FxaaFloat maxWN = max(lumaN, lumaW);
    FxaaFloat minWN = min(lumaN, lumaW);
    FxaaFloat rangeMax = max(maxWN, maxESM);
    FxaaFloat rangeMin = min(minWN, minESM);
    FxaaFloat rangeMaxScaled = rangeMax * fxaaQualityEdgeThreshold;
    FxaaFloat range = rangeMax - rangeMin;
    FxaaFloat rangeMaxClamped = max(fxaaQualityEdgeThresholdMin, rangeMaxScaled);
    FxaaBool earlyExit = range < rangeMaxClamped;
/*--------------------------------------------------------------------------*/
    if(earlyExit)
        #if (FXAA_DISCARD == 1)
            FxaaDiscard;
        #else
            return rgbyM;
        #endif
/*--------------------------------------------------------------------------*/
    #if (FXAA_GATHER4_ALPHA == 0)
        FxaaFloat lumaNW = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2(-1,-1), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaSE = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2( 1, 1), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaNE = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2( 1,-1), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaSW = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2(-1, 1), fxaaQualityRcpFrame.xy));
    #else
        FxaaFloat lumaNE = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2(1, -1), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaSW = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2(-1, 1), fxaaQualityRcpFrame.xy));
    #endif
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNS = lumaN + lumaS;
    FxaaFloat lumaWE = lumaW + lumaE;
    FxaaFloat subpixRcpRange = 1.0/range;
    FxaaFloat subpixNSWE = lumaNS + lumaWE;
    FxaaFloat edgeHorz1 = (-2.0 * lumaM) + lumaNS;
    FxaaFloat edgeVert1 = (-2.0 * lumaM) + lumaWE;
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNESE = lumaNE + lumaSE;
    FxaaFloat lumaNWNE = lumaNW + lumaNE;
    FxaaFloat edgeHorz2 = (-2.0 * lumaE) + lumaNESE;
    FxaaFloat edgeVert2 = (-2.0 * lumaN) + lumaNWNE;
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNWSW = lumaNW + lumaSW;
    FxaaFloat lumaSWSE = lumaSW + lumaSE;
    FxaaFloat edgeHorz4 = (abs(edgeHorz1) * 2.0) + abs(edgeHorz2);
    FxaaFloat edgeVert4 = (abs(edgeVert1) * 2.0) + abs(edgeVert2);
    FxaaFloat edgeHorz3 = (-2.0 * lumaW) + lumaNWSW;
    FxaaFloat edgeVert3 = (-2.0 * lumaS) + lumaSWSE;
    FxaaFloat edgeHorz = abs(edgeHorz3) + edgeHorz4;
    FxaaFloat edgeVert = abs(edgeVert3) + edgeVert4;
/*--------------------------------------------------------------------------*/
    FxaaFloat subpixNWSWNESE = lumaNWSW + lumaNESE;
    FxaaFloat lengthSign = fxaaQualityRcpFrame.x;
    FxaaBool horzSpan = edgeHorz >= edgeVert;
    FxaaFloat subpixA = subpixNSWE * 2.0 + subpixNWSWNESE;
/*--------------------------------------------------------------------------*/
    if(!horzSpan) lumaN = lumaW;
    if(!horzSpan) lumaS = lumaE;
    if(horzSpan) lengthSign = fxaaQualityRcpFrame.y;
    FxaaFloat subpixB = (subpixA * (1.0/12.0)) - lumaM;
/*--------------------------------------------------------------------------*/
    FxaaFloat gradientN = lumaN - lumaM;
    FxaaFloat gradientS = lumaS - lumaM;
    FxaaFloat lumaNN = lumaN + lumaM;
    FxaaFloat lumaSS = lumaS + lumaM;
    FxaaBool pairN = abs(gradientN) >= abs(gradientS);
    FxaaFloat gradient = max(abs(gradientN), abs(gradientS));
    if(pairN) lengthSign = -lengthSign;
    FxaaFloat subpixC = FxaaSat(abs(subpixB) * subpixRcpRange);
/*--------------------------------------------------------------------------*/
    FxaaFloat2 posB;
    posB.x = posM.x;
    posB.y = posM.y;
    FxaaFloat2 offNP;
    offNP.x = (!horzSpan) ? 0.0 : fxaaQualityRcpFrame.x;
    offNP.y = ( horzSpan) ? 0.0 : fxaaQualityRcpFrame.y;
    if(!horzSpan) posB.x += lengthSign * 0.5;
    if( horzSpan) posB.y += lengthSign * 0.5;
/*--------------------------------------------------------------------------*/
    FxaaFloat2 posN;
    posN.x = posB.x - offNP.x * FXAA_QUALITY__P0;
    posN.y = posB.y - offNP.y * FXAA_QUALITY__P0;
    FxaaFloat2 posP;
    posP.x = posB.x + offNP.x * FXAA_QUALITY__P0;
    posP.y = posB.y + offNP.y * FXAA_QUALITY__P0;
    FxaaFloat subpixD = ((-2.0)*subpixC) + 3.0;
    FxaaFloat lumaEndN = FxaaLuma(FxaaTexTop(tex, posN));
    FxaaFloat subpixE = subpixC * subpixC;
    FxaaFloat lumaEndP = FxaaLuma(FxaaTexTop(tex, posP));
/*--------------------------------------------------------------------------*/
    if(!pairN) lumaNN = lumaSS;
    FxaaFloat gradientScaled = gradient * 1.0/4.0;
    FxaaFloat lumaMM = lumaM - lumaNN * 0.5;
    FxaaFloat subpixF = subpixD * subpixE;
    FxaaBool lumaMLTZero = lumaMM < 0.0;
/*--------------------------------------------------------------------------*/
    lumaEndN -= lumaNN * 0.5;
    lumaEndP -= lumaNN * 0.5;
    FxaaBool doneN = abs(lumaEndN) >= gradientScaled;
    FxaaBool doneP = abs(lumaEndP) >= gradientScaled;
    if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P1;
    if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P1;
    FxaaBool doneNP = (!doneN) || (!doneP);
    if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P1;
    if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P1;
/*--------------------------------------------------------------------------*/
    if(doneNP) {
        if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
        if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
        doneN = abs(lumaEndN) >= gradientScaled;
        doneP = abs(lumaEndP) >= gradientScaled;
        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P2;
        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P2;
        doneNP = (!doneN) || (!doneP);
        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P2;
        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P2;
/*--------------------------------------------------------------------------*/
        #if (FXAA_QUALITY__PS > 3)
        if(doneNP) {
            if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
            if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
            if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
            if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
            doneN = abs(lumaEndN) >= gradientScaled;
            doneP = abs(lumaEndP) >= gradientScaled;
            if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P3;
            if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P3;
            doneNP = (!doneN) || (!doneP);
            if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P3;
            if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P3;
/*--------------------------------------------------------------------------*/
            #if (FXAA_QUALITY__PS > 4)
            if(doneNP) {
                if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                doneN = abs(lumaEndN) >= gradientScaled;
                doneP = abs(lumaEndP) >= gradientScaled;
                if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P4;
                if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P4;
                doneNP = (!doneN) || (!doneP);
                if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P4;
                if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P4;
/*--------------------------------------------------------------------------*/
                #if (FXAA_QUALITY__PS > 5)
                if(doneNP) {
                    if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                    if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                    if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                    if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                    doneN = abs(lumaEndN) >= gradientScaled;
                    doneP = abs(lumaEndP) >= gradientScaled;
                    if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P5;
                    if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P5;
                    doneNP = (!doneN) || (!doneP);
                    if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P5;
                    if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P5;
/*--------------------------------------------------------------------------*/
                    #if (FXAA_QUALITY__PS > 6)
                    if(doneNP) {
                        if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                        if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                        doneN = abs(lumaEndN) >= gradientScaled;
                        doneP = abs(lumaEndP) >= gradientScaled;
                        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P6;
                        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P6;
                        doneNP = (!doneN) || (!doneP);
                        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P6;
                        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P6;
/*--------------------------------------------------------------------------*/
                        #if (FXAA_QUALITY__PS > 7)
                        if(doneNP) {
                            if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                            if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                            if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                            if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                            doneN = abs(lumaEndN) >= gradientScaled;
                            doneP = abs(lumaEndP) >= gradientScaled;
                            if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P7;
                            if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P7;
                            doneNP = (!doneN) || (!doneP);
                            if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P7;
                            if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P7;
/*--------------------------------------------------------------------------*/
    #if (FXAA_QUALITY__PS > 8)
    if(doneNP) {
        if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
        if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
        doneN = abs(lumaEndN) >= gradientScaled;
        doneP = abs(lumaEndP) >= gradientScaled;
        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P8;
        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P8;
        doneNP = (!doneN) || (!doneP);
        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P8;
        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P8;
/*--------------------------------------------------------------------------*/
        #if (FXAA_QUALITY__PS > 9)
        if(doneNP) {
            if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
            if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
            if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
            if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
            doneN = abs(lumaEndN) >= gradientScaled;
            doneP = abs(lumaEndP) >= gradientScaled;
            if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P9;
            if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P9;
            doneNP = (!doneN) || (!doneP);
            if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P9;
            if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P9;
/*--------------------------------------------------------------------------*/
            #if (FXAA_QUALITY__PS > 10)
            if(doneNP) {
                if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                doneN = abs(lumaEndN) >= gradientScaled;
                doneP = abs(lumaEndP) >= gradientScaled;
                if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P10;
                if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P10;
                doneNP = (!doneN) || (!doneP);
                if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P10;
                if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P10;
/*--------------------------------------------------------------------------*/
                #if (FXAA_QUALITY__PS > 11)
                if(doneNP) {
                    if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                    if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                    if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                    if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                    doneN = abs(lumaEndN) >= gradientScaled;
                    doneP = abs(lumaEndP) >= gradientScaled;
                    if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P11;
                    if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P11;
                    doneNP = (!doneN) || (!doneP);
                    if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P11;
                    if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P11;
/*--------------------------------------------------------------------------*/
                    #if (FXAA_QUALITY__PS > 12)
                    if(doneNP) {
                        if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                        if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                        doneN = abs(lumaEndN) >= gradientScaled;
                        doneP = abs(lumaEndP) >= gradientScaled;
                        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P12;
                        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P12;
                        doneNP = (!doneN) || (!doneP);
                        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P12;
                        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P12;
/*--------------------------------------------------------------------------*/
                    }
                    #endif
/*--------------------------------------------------------------------------*/
                }
                #endif
/*--------------------------------------------------------------------------*/
            }
            #endif
/*--------------------------------------------------------------------------*/
        }
        #endif
/*--------------------------------------------------------------------------*/
    }
    #endif
/*--------------------------------------------------------------------------*/
                        }
                        #endif
/*--------------------------------------------------------------------------*/
                    }
                    #endif
/*--------------------------------------------------------------------------*/
                }
                #endif
/*--------------------------------------------------------------------------*/
            }
            #endif
/*--------------------------------------------------------------------------*/
        }
        #endif
/*--------------------------------------------------------------------------*/
    }
/*--------------------------------------------------------------------------*/
    FxaaFloat dstN = posM.x - posN.x;
    FxaaFloat dstP = posP.x - posM.x;
    if(!horzSpan) dstN = posM.y - posN.y;
    if(!horzSpan) dstP = posP.y - posM.y;
/*--------------------------------------------------------------------------*/
    FxaaBool goodSpanN = (lumaEndN < 0.0) != lumaMLTZero;
    FxaaFloat spanLength = (dstP + dstN);
    FxaaBool goodSpanP = (lumaEndP < 0.0) != lumaMLTZero;
    FxaaFloat spanLengthRcp = 1.0/spanLength;
/*--------------------------------------------------------------------------*/
    FxaaBool directionN = dstN < dstP;
    FxaaFloat dst = min(dstN, dstP);
    FxaaBool goodSpan = directionN ? goodSpanN : goodSpanP;
    FxaaFloat subpixG = subpixF * subpixF;
    FxaaFloat pixelOffset = (dst * (-spanLengthRcp)) + 0.5;
    FxaaFloat subpixH = subpixG * fxaaQualitySubpix;
/*--------------------------------------------------------------------------*/
    FxaaFloat pixelOffsetGood = goodSpan ? pixelOffset : 0.0;
    FxaaFloat pixelOffsetSubpix = max(pixelOffsetGood, subpixH);
    if(!horzSpan) posM.x += pixelOffsetSubpix * lengthSign;
    if( horzSpan) posM.y += pixelOffsetSubpix * lengthSign;
    #if (FXAA_DISCARD == 1)
        return FxaaTexTop(tex, posM);
    #else
        return FxaaFloat4(FxaaTexTop(tex, posM).xyz, lumaM);
    #endif
}
/*==========================================================================*/
#endif

/*============================================================================

                         FXAA3 CONSOLE - PC VERSION
                         
------------------------------------------------------------------------------
Instead of using this on PC, I'd suggest just using FXAA Quality with
    #define FXAA_QUALITY_PRESET 10
Or 
    #define FXAA_QUALITY_PRESET 20
Either are higher quality and almost as fast as this on modern PC GPUs.
============================================================================*/
#if (FXAA_PC_CONSOLE == 1)
/*--------------------------------------------------------------------------*/
FxaaFloat4 FxaaPixelShader(
    //
    // Use noperspective interpolation here (turn off perspective interpolation).
    // {xy} = center of pixel
    highp FxaaFloat2 pos,
    //
    // Used only for FXAA Console, and not used on the 360 version.
    // Use noperspective interpolation here (turn off perspective interpolation).
    // {xy__} = upper left of pixel
    // {__zw} = lower right of pixel
    highp FxaaFloat4 fxaaConsolePosPos,
    //
    // Input color texture.
    // {rgb_} = color in linear or perceptual color space
    // if (FXAA_GREEN_AS_LUMA == 0)
    //     {___a} = luma in perceptual color space (not linear)
    FxaaTex tex,
    //
    // Only used on FXAA Console.
    // This must be from a constant/uniform.
    // This effects sub-pixel AA quality and inversely sharpness.
    //   Where N ranges between,
    //     N = 0.50 (default)
    //     N = 0.33 (sharper)
    // {__z_} =  N/screenWidthInPixels
    // {___w} =  N/screenHeightInPixels
    highp FxaaFloat2 fxaaConsoleRcpFrameOpt,
    //
    // Only used on FXAA Console.
    // Not used on 360, but used on PS3 and PC.
    // This must be from a constant/uniform.
    // {__z_} =  2.0/screenWidthInPixels
    // {___w} =  2.0/screenHeightInPixels
    highp FxaaFloat2 fxaaConsoleRcpFrameOpt2,
    //
    // Only used on FXAA Console.
    // This used to be the FXAA_CONSOLE__EDGE_SHARPNESS define.
    // It is here now to allow easier tuning.
    // This does not effect PS3, as this needs to be compiled in.
    //   Use FXAA_CONSOLE__PS3_EDGE_SHARPNESS for PS3.
    //   Due to the PS3 being ALU bound,
    //   there are only three safe values here: 2 and 4 and 8.
    //   These options use the shaders ability to a free *|/ by 2|4|8.
    // For all other platforms can be a non-power of two.
    //   8.0 is sharper (default!!!)
    //   4.0 is softer
    //   2.0 is really soft (good only for vector graphics inputs)
    FxaaFloat fxaaConsoleEdgeSharpness,
    //
    // Only used on FXAA Console.
    // This used to be the FXAA_CONSOLE__EDGE_THRESHOLD define.
    // It is here now to allow easier tuning.
    // This does not effect PS3, as this needs to be compiled in.
    //   Use FXAA_CONSOLE__PS3_EDGE_THRESHOLD for PS3.
    //   Due to the PS3 being ALU bound,
    //   there are only two safe values here: 1/4 and 1/8.
    //   These options use the shaders ability to a free *|/ by 2|4|8.
    // The console setting has a different mapping than the quality setting.
    // Other platforms can use other values.
    //   0.125 leaves less aliasing, but is softer (default!!!)
    //   0.25 leaves more aliasing, and is sharper
    FxaaFloat fxaaConsoleEdgeThreshold,
    //
    // Only used on FXAA Console.
    // This used to be the FXAA_CONSOLE__EDGE_THRESHOLD_MIN define.
    // It is here now to allow easier tuning.
    // Trims the algorithm from processing darks.
    // The console setting has a different mapping than the quality setting.
    // This only applies when FXAA_EARLY_EXIT is 1.
    // This does not apply to PS3,
    // PS3 was simplified to avoid more shader instructions.
    //   0.06 - faster but more aliasing in darks
    //   0.05 - default
    //   0.04 - slower and less aliasing in darks
    // Special notes when using FXAA_GREEN_AS_LUMA,
    //   Likely want to set this to zero.
    //   As colors that are mostly not-green
    //   will appear very dark in the green channel!
    //   Tune by looking at mostly non-green content,
    //   then start at zero and increase until aliasing is a problem.
    FxaaFloat fxaaConsoleEdgeThresholdMin
) {
    // Corners: average luma of four corners
    FxaaFloat lumaNw = FxaaLuma(FxaaTexTop(tex, fxaaConsolePosPos.xy));
    FxaaFloat lumaSw = FxaaLuma(FxaaTexTop(tex, fxaaConsolePosPos.xw));
    FxaaFloat lumaNe = FxaaLuma(FxaaTexTop(tex, fxaaConsolePosPos.zy));
    FxaaFloat lumaSe = FxaaLuma(FxaaTexTop(tex, fxaaConsolePosPos.zw));

    // Read the middle RGB and luma
    FxaaFloat4 rgbyM = FxaaTexTop(tex, pos.xy);
    FxaaFloat lumaM = FxaaLuma(rgbyM);

    // Find the largest and smallest luminance value of the four corners.
    FxaaFloat lumaMaxNwSw = max(lumaNw, lumaSw);
    // Lottes' original bias to avoid later divide by zero.  We bias
    // the actual term required below.  In each case, the bias should be
    // less than one intensity gradiation at 8-bit
#   if G3D_FXAA_PATCHES == 0
        lumaNe += 1.0 / 384.0;
#   endif
    FxaaFloat lumaMinNwSw = min(lumaNw, lumaSw);
    FxaaFloat lumaMaxNeSe = max(lumaNe, lumaSe);
    FxaaFloat lumaMinNeSe = min(lumaNe, lumaSe);
    FxaaFloat lumaMax = max(lumaMaxNeSe, lumaMaxNwSw);
    FxaaFloat lumaMin = min(lumaMinNeSe, lumaMinNwSw);

    // The threshold for a luminance edge
    FxaaFloat lumaMaxScaled = lumaMax * fxaaConsoleEdgeThreshold;

    // Min, including the center
    FxaaFloat lumaMinM = min(lumaMin, lumaM);
    FxaaFloat lumaMaxScaledClamped = max(fxaaConsoleEdgeThresholdMin, lumaMaxScaled);

    // Max, including the center
    FxaaFloat lumaMaxM = max(lumaMax, lumaM);

    // Total range within a 3x3 neighborhood, for thresholding
    // whether it is worth appling AA
    FxaaFloat lumaMaxSubMinM = lumaMaxM - lumaMinM;

    // If the entire range is less than the edge threshold, apply no AA
    if (lumaMaxSubMinM < lumaMaxScaledClamped) { return rgbyM; }

    // Diagonal gradient (biased to avoid a later divide by zero)
    FxaaFloat dirSwMinusNe = lumaSw - lumaNe;

    // Other diagonal gradient
    FxaaFloat dirSeMinusNw = lumaSe - lumaNw;

    // Tangent to the edge
    FxaaFloat2 dir = FxaaFloat2(
        dirSwMinusNe + dirSeMinusNw, // == (SW + SE) - (NE + NW) ~= S - N
        dirSwMinusNe - dirSeMinusNw  // == (SW + NW) - (SE + NE) ~= W - E
    );

    // Avoid a division by 0 when normalizing dir
    // Should we instead do the following?
    //     FxaaFloat2 dir1 = dir.xy / (length(dir) + MEDIUMP_FLT_MIN);
    // Or even the following?
    //     FxaaFloat2 dir1 = dirLength < MEDIUMP_FLT_MIN ? FxaaFloat2(0.0) : dir.xy / dirLength
    FxaaFloat dirLength = length(dir.xy);
    if (dirLength < MEDIUMP_FLT_MIN) { return rgbyM; }

    FxaaFloat2 dir1 = dir.xy / dirLength;

    // Step one pixel-width along the tangent in both the positive and negative half
    // spaces and sample there
    FxaaFloat4 rgbyN1 = FxaaTexTop(tex, pos.xy - dir1 * fxaaConsoleRcpFrameOpt.xy);
    FxaaFloat4 rgbyP1 = FxaaTexTop(tex, pos.xy + dir1 * fxaaConsoleRcpFrameOpt.xy);

#   if G3D_FXAA_PATCHES
        // A second sample up to two pixels away along the tangent.  This is a "min" in the original.
        //  We increase the distance (i.e., amount of blur) as the luma contrast increases.
        FxaaFloat dirAbsMinTimesC = max(abs(dir1.x), abs(dir1.y)) * fxaaConsoleEdgeSharpness * 0.015;
        FxaaFloat2 dir2 = dir1.xy * min(lumaMaxSubMinM / dirAbsMinTimesC, 3.0);
#   else
        FxaaFloat dirAbsMinTimesC = min(abs(dir1.x), abs(dir1.y)) * fxaaConsoleEdgeSharpness;
        FxaaFloat2 dir2 = clamp(dir1.xy / dirAbsMinTimesC, vec2(-2.0), vec2(2.0));
#   endif
    FxaaFloat4 rgbyN2 = FxaaTexTop(tex, pos.xy - dir2 * fxaaConsoleRcpFrameOpt2.xy);
    FxaaFloat4 rgbyP2 = FxaaTexTop(tex, pos.xy + dir2 * fxaaConsoleRcpFrameOpt2.xy);

    // (twice the) average of adjacent pixels on the tangent directions
    FxaaFloat4 rgbyA = rgbyN1 + rgbyP1;

    // Average of four adjacent pixels on the tangent direction
    FxaaFloat4 rgbyB = ((rgbyN2 + rgbyP2) * 0.25) + (rgbyA * 0.25);

    // If the 4-tap average along the tangent directions is much different from
    // the range of the original, go back to the 2-tap average. 
    // Otherwise, use the 4-tap average.  Considering this threshold avoids some
    // ringing and blurring at object edges
    FxaaBool twoTap = (FxaaLuma(rgbyB) < lumaMin) || (FxaaLuma(rgbyB) > lumaMax);
    if (twoTap) { rgbyB.xyz = rgbyA.xyz * 0.5; }

#   if G3D_FXAA_PATCHES
        // Keep some of the original contribution to avoid thin lines degrading completely
        // and overblurring. This is an addition to the original Lottes algorithm
        // rgbyB = sqrt(lerp(rgbyB * rgbyB, rgbyM * rgbyM, 0.25));  // Luminance preserving
        rgbyB = lerp(rgbyB, rgbyM, 0.25); // Faster
#   endif
    return rgbyB; 
}
/*==========================================================================*/
#endif
