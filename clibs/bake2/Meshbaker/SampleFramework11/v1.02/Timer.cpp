//=================================================================================================
//
//	MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "Timer.h"

#include "Utility.h"

namespace SampleFramework11
{

Timer::Timer()
{
    // Query for the performance counter frequency
    LARGE_INTEGER largeInt;
    Win32Call(QueryPerformanceFrequency(&largeInt));
    frequency = largeInt.QuadPart;
    frequencyD = static_cast<double>(frequency);

    // Init the elapsed time
    Win32Call(QueryPerformanceCounter(&largeInt));
    startTime = largeInt.QuadPart;
    elapsed = largeInt.QuadPart - startTime;
    elapsedF = static_cast<float>(elapsed);
    elapsedSeconds = elapsed / frequency;
    elapsedSecondsD = elapsed / frequencyD;
    elapsedSecondsF = static_cast<float>(elapsedSecondsD);
    elapsedMilliseconds = static_cast<int64>(elapsedSecondsD * 1000);
    elapsedMillisecondsD = elapsedSecondsD * 1000;
    elapsedMillisecondsF = static_cast<float>(elapsedMillisecondsD);
    elapsedMicroseconds = static_cast<int64>(elapsedMillisecondsD * 1000);
    elapsedMicrosecondsD = elapsedMillisecondsD * 1000;
    elapsedMicrosecondsF = static_cast<float>(elapsedMillisecondsD);

    delta = 0;
    deltaF = 0;
    deltaMilliseconds = 0;
    deltaMillisecondsF = 0;
    deltaMicroseconds = 0;
    deltaMicrosecondsF = 0;
}

Timer::~Timer()
{
}

void Timer::Update()
{
    LARGE_INTEGER largeInt;
    Win32Call(QueryPerformanceCounter(&largeInt));
    int64 currentTime = largeInt.QuadPart - startTime;
    delta = currentTime - elapsed;
    deltaF = static_cast<float>(deltaF);
    deltaSeconds = delta / frequency;
    deltaSecondsD = delta / frequencyD;
    deltaSecondsF = static_cast<float>(deltaSecondsD);
    deltaMillisecondsD = deltaSecondsD * 1000;
    deltaMilliseconds = static_cast<int64>(deltaMillisecondsD);
    deltaMillisecondsF = static_cast<float>(deltaMillisecondsD);
    deltaMicrosecondsD = deltaMillisecondsD * 1000;
    deltaMicroseconds = static_cast<int64>(deltaMicrosecondsD);
    deltaMicrosecondsF = static_cast<float>(deltaMicrosecondsD);

    elapsed = currentTime;
    elapsedF = static_cast<float>(elapsed);
    elapsedSeconds = elapsed / frequency;
    elapsedSecondsD = elapsed / frequencyD;
    elapsedSecondsF = static_cast<float>(elapsedSecondsD);
    elapsedMilliseconds = static_cast<int64>(elapsedSecondsD * 1000);
    elapsedMillisecondsD = elapsedSecondsD * 1000;
    elapsedMillisecondsF = static_cast<float>(elapsedMillisecondsD);
    elapsedMicroseconds = static_cast<int64>(elapsedMillisecondsD * 1000);
    elapsedMicrosecondsD = elapsedMillisecondsD * 1000;
    elapsedMicrosecondsF = static_cast<float>(elapsedMillisecondsD);
}

int64 Timer::ElapsedSeconds() const
{
    return elapsedSeconds;
}

float Timer::ElapsedSecondsF() const
{
    return elapsedSecondsF;
}

double Timer::ElapsedSecondsD() const
{
    return elapsedSecondsD;
}

int64 Timer::DeltaSeconds() const
{
    return deltaSeconds;
}

float Timer::DeltaSecondsF() const
{
    return deltaSecondsF;
}

double Timer::DeltaSecondsD() const
{
    return deltaSecondsD;
}

int64 Timer::ElapsedMilliseconds() const
{
    return elapsedMilliseconds;
}

float Timer::ElapsedMillisecondsF() const
{
    return elapsedMillisecondsF;
}

double Timer::ElapsedMillisecondsD() const
{
    return elapsedMillisecondsD;
}

int64 Timer::DeltaMilliseconds() const
{
    return deltaMilliseconds;
}

float Timer::DeltaMillisecondsF() const
{
    return deltaMillisecondsF;
}

double Timer::DeltaMillisecondsD() const
{
    return deltaMillisecondsD;
}

int64 Timer::ElapsedMicroseconds() const
{
    return elapsedMicroseconds;
}

float Timer::ElapsedMicrosecondsF() const
{
    return elapsedMicrosecondsF;
}

double Timer::ElapsedMicrosecondsD() const
{
    return elapsedMicrosecondsD;
}

int64 Timer::DeltaMicroseconds() const
{
    return deltaMicroseconds;
}

float Timer::DeltaMicrosecondsF() const
{
    return deltaMicrosecondsF;
}

double Timer::DeltaMicrosecondsD() const
{
    return deltaMicrosecondsD;
}

}