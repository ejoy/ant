//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#ifndef CONSTANTS_HLSL_
#define CONSTANTS_HLSL_

static const float Pi = 3.141592654f;
static const float Pi2 = 6.283185307f;
static const float Pi_2 = 1.570796327f;
static const float Pi_4 = 0.7853981635f;
static const float InvPi = 0.318309886f;
static const float InvPi2 = 0.159154943f;

// Max value that we can store in an fp16 buffer (actually a little less so that we have room for error, real max is 65504)
static const float FP16Max = 65000.0f;

// Scale factor used for storing physical light units in fp16 floats (equal to 2^-10).
static const float FP16Scale = 0.0009765625f;

#endif // CONSTANTS_HLSL_