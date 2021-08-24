//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "..\\PCH.h"
#include "..\\InterfacePointers.h"
#include "..\\Timer.h"

namespace SampleFramework11
{

class SpriteRenderer;
class SpriteFont;

class Profiler
{

public:

    static Profiler GlobalProfiler;

    void Initialize(ID3D11Device* device, ID3D11DeviceContext* immContext);

    void StartProfile(const std::wstring& name);
    void EndProfile(const std::wstring& name);

    void StartCPUProfile(const std::wstring& name);
    void EndCPUProfile(const std::wstring& name);

    void EndFrame(SpriteRenderer& spriteRenderer, SpriteFont& spriteFont);

protected:

    // Constants
    static const uint64 QueryLatency = 5;

    struct ProfileData
    {
        ID3D11QueryPtr DisjointQuery[QueryLatency];
        ID3D11QueryPtr TimestampStartQuery[QueryLatency];
        ID3D11QueryPtr TimestampEndQuery[QueryLatency];
        bool QueryStarted;
        bool QueryFinished;
        bool Active;

        bool CPUProfile;
        int64 StartTime;
        int64 EndTime;

        static const uint32 FilterSize = 64;
        double TimeSamples[FilterSize];
        uint32 CurrSample;

        ProfileData() : QueryStarted(false), QueryFinished(false), Active(false),
                        CPUProfile(false), StartTime(0), EndTime(0), CurrSample(0)
        {
            for(uint32 i = 0; i < FilterSize; ++i)
                TimeSamples[i] = 0.0;
        }
    };

    typedef std::map<std::wstring, ProfileData> ProfileMap;

    ProfileMap profiles;
    uint64 currFrame;

    ID3D11DevicePtr device;
    ID3D11DeviceContextPtr context;

    Timer timer;
};

class ProfileBlock
{
public:

    ProfileBlock(const std::wstring& name);
    ~ProfileBlock();

protected:

    std::wstring name;
};

class CPUProfileBlock
{
public:

    CPUProfileBlock(const std::wstring& name);
    ~CPUProfileBlock();

protected:

    std::wstring name;
};

}
