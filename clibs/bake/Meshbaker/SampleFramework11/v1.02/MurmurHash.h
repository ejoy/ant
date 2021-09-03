//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "PCH.h"

namespace SampleFramework11
{

struct Hash
{
    uint64 A;
    uint64 B;

    Hash() : A(0), B(0) {}
    Hash(uint64 a, uint64 b) : A(a), B(b) {}

    std::wstring ToString() const;

    bool operator==(const Hash& other)
    {
        return A == other.A && B == other.B;
    }
};

Hash GenerateHash(const void* key, int len, uint32 seed = 0);

}