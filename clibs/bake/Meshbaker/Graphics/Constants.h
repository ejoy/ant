#pragma once
#include <limits>
#include <cstdint>

const float Pi = 3.141592654f;
const float Pi2 = 6.283185307f;
const float Pi_2 = 1.570796327f;
const float Pi_4 = 0.7853981635f;
const float InvPi = 0.318309886f;
const float InvPi2 = 0.159154943f;

// Max value that we can store in an fp16 buffer (actually a little less so that we have room for error, real max is 65504)
const float FP16Max = 65000.0f;

// Scale factor used for storing physical light units in fp16 floats (equal to 2^-10).
const float FP16Scale = 0.0009765625f;

const float FloatMax = std::numeric_limits<float>::max();
const float FloatInfinity = std::numeric_limits<float>::infinity();

typedef uint32_t bool32;