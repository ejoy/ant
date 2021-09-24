#pragma once

#include "Assert_.h"
#include "Utility.h"
enum class SkyModes
{
    None = 0,
    Procedural = 1,
    Simple = 2,
    CubeMapEnnis = 3,
    CubeMapGraceCathedral = 4,
    CubeMapUffizi = 5,

    NumValues
};

enum class SGDiffuseModes
{
    InnerProduct = 0,
    Punctual = 1,
    Fitted = 2,

    NumValues
};


enum class SGSpecularModes
{
    Punctual = 0,
    SGWarp = 1,
    ASGWarp = 2,

    NumValues
};


enum class SH4DiffuseModes
{
    Convolution = 0,
    Geomerics = 1,

    NumValues
};

enum class SHSpecularModes
{
    Convolution = 0,
    DominantDirection = 1,
    Punctual = 2,
    Prefiltered = 3,

    NumValues
};


enum class SampleModes
{
    Random = 0,
    Stratified = 1,
    Hammersley = 2,
    UniformGrid = 3,
    CMJ = 4,

    NumValues
};

enum class BakeModes
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

enum class SolveModes
{
    Projection = 0,
    SVD = 1,
    NNLS = 2,
    RunningAverage = 3,
    RunningAverageNN = 4,

    NumValues
};

enum class BRDF
{
    GGX = 0,
    Beckmann = 1,
    Velvet = 2,

    NumValues
};


struct BakeSetting{
    static const int64 MaxSGCount = 12;
    static const int64 MaxBasisCount = 12;

    static const uint64 TileSize = 16;
    static const uint64 BakeGroupSizeX = 8;
    static const uint64 BakeGroupSizeY = 8;
    static const uint64 BakeGroupSize = BakeGroupSizeX * BakeGroupSizeY;
    
    int32 MaxBakePathLength = -1;
    int32 BakeRussianRouletteDepth = 4;
    float BakeRussianRouletteProbability = 0.5000f;

    uint64 NumBakeSample = 25;   // range from[0, 100]
    BakeModes BakeMode = BakeModes::Diffuse;
    SampleModes SampleMode = SampleModes::Random;

    SolveModes SolveMode;

    SH4DiffuseModes SH4DiffuseMode;
    SHSpecularModes SHSpecularMode;

    SGDiffuseModes SGDiffuseMode;
    SGSpecularModes SGSpecularMode;

    inline uint64 BasisCount() const
    {
        const uint32 bm = (uint32)BakeMode;
        Assert_(bm < uint64(BakeModes::NumValues));
        static const uint64 BasisCounts[] = { 1, 2, 4, 3, 4, 9, 4, 6, 5, 6, 9, 12 };
        StaticAssert_(ArraySize_(BasisCounts) == uint64(BakeModes::NumValues));
        Assert_(BasisCounts[bm] <= MaxBasisCount);
        return BasisCounts[bm];
    }

    inline uint64 SGCount() const
    {
        Assert_(uint64(BakeMode) < uint64(BakeModes::NumValues));
        return (uint64(BakeMode) >= uint64(BakeModes::SG5)) ?
            BasisCount() : 0;
    }

    inline bool SupportsProgressiveIntegration() const
    {
        if((BakeMode == BakeModes::Directional) || (BakeMode == BakeModes::DirectionalRGB) || 
            (SGCount() > 0 && (SolveMode == SolveModes::SVD || SolveMode == SolveModes::NNLS)))
            return false;
        else
            return true;
    }

    inline uint64 NumBakeBatches(uint64 numGroupX, uint64 numGroupY) const {
        return SupportsProgressiveIntegration() ?
            numGroupX * numGroupY * NumBakeSample * NumBakeSample : 
            numGroupX * numGroupY * BakeGroupSize;
    }
};


const BakeSetting& GetBakeSetting();
