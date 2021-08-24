//just for code compatible
#pragma once
#include <cstdint>
#include "glm/glm.hpp"

enum class SampleModes
{
    Random = 0,
    Stratified = 1,
    Hammersley = 2,
    UniformGrid = 3,
    CMJ = 4,

    NumValues
};


enum class BakeModes : uint8_t
{
    Diffuse = 0,
    Directional = 1,
    DirectionalRGB = 2,
    HL2 = 3,
    SH4 = 4,
    SH9 = 5,
    H4 = 6,
    H6 = 7,
    SG5 = 8,
    SG6 = 9,
    SG9 = 10,
    SG12 = 11,

    NumValues
};

enum class SolveModes : uint8_t
{
    Projection = 0,
    SVD = 1,
    NNLS = 2,
    RunningAverage = 3,
    RunningAverageNN = 4,

    NumValues
};

namespace Setting{
    static const float BaseSunSize = 0.2700f;
    static const int64_t MaxSGCount = 12;
    static const int64_t MaxBasisCount = 12;
    extern BakeModes BakeMode;
    extern SolveModes SolveMode;
    extern bool EnableAlbedoMaps;
    extern bool EnableSun;
    extern float SunSize;
    extern glm::vec3 SunDirection;

    extern bool EnableAreaLightShadows;

    glm::vec3 SunLuminance();
    glm::vec3 SunIlluminance();
};