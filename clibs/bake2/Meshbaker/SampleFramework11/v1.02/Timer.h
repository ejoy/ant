//=================================================================================================
//
//	MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "PCH.h"

namespace SampleFramework11
{

class Timer
{

public:

    Timer();
    ~Timer();

    void Update();

    int64 ElapsedSeconds() const;
    float ElapsedSecondsF() const;
    double ElapsedSecondsD() const;
    int64 DeltaSeconds() const;
    float DeltaSecondsF() const;
    double DeltaSecondsD() const;

    int64 ElapsedMilliseconds() const;
    float ElapsedMillisecondsF() const;
    double ElapsedMillisecondsD() const;
    int64 DeltaMilliseconds() const;
    float DeltaMillisecondsF() const;
    double DeltaMillisecondsD() const;

    int64 ElapsedMicroseconds() const;
    float ElapsedMicrosecondsF() const;
    double ElapsedMicrosecondsD() const;
    int64 DeltaMicroseconds() const;
    float DeltaMicrosecondsF() const;
    double DeltaMicrosecondsD() const;

protected:

    int64 startTime;

    int64 frequency;
    double frequencyD;

    int64 elapsed;
    int64 delta;

    float elapsedF;
    float deltaF;

    double elapsedD;
    double deltaD;

    int64 elapsedSeconds;
    int64 deltaSeconds;

    float elapsedSecondsF;
    float deltaSecondsF;

    double elapsedSecondsD;
    double deltaSecondsD;

    int64 elapsedMilliseconds;
    int64 deltaMilliseconds;

    float elapsedMillisecondsF;
    float deltaMillisecondsF;

    double elapsedMillisecondsD;
    double deltaMillisecondsD;

    int64 elapsedMicroseconds;
    int64 deltaMicroseconds;

    float elapsedMicrosecondsF;
    float deltaMicrosecondsF;

    double elapsedMicrosecondsD;
    double deltaMicrosecondsD;
};

}