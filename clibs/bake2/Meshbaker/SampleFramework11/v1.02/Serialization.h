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

#include "Exceptions.h"
#include "FileIO.h"

namespace SampleFramework11
{

class FileReadSerializer
{

private:

    File file;

public:

    explicit FileReadSerializer(const wchar* path)
    {
        file.Open(path, FileOpenMode::Read);
    }

    template<typename T> void SerializeItem(T& data)
    {
        file.Read(data);
    }

    void SerializeData(uint64 size, void* data)
    {
        file.Read(size, data);
    }

    static bool IsReadSerializer() { return true; }
    static bool IsWriteSerializer() { return false; }
};

class FileWriteSerializer
{

private:

    File file;

public:

    explicit FileWriteSerializer(const wchar* path)
    {
        file.Open(path, FileOpenMode::Write);
    }

    template<typename T> void SerializeItem(const T& data)
    {
        file.Write(data);
    }

    void SerializeData(uint64 size, const void* data)
    {
        file.Write(size, data);
    }

    static bool IsReadSerializer() { return false; }
    static bool IsWriteSerializer() { return true; }
};

class ComputeSizeSerializer
{

private:

    uint64 numBytes = 0;

public:

    template<typename T> void SerializeItem(const T& data)
    {
        numBytes += sizeof(T);
    }

    void SerializeData(uint64 size, const void* data)
    {
        numBytes += size;
    }

    static bool IsReadSerializer() { return false; }
    static bool IsWriteSerializer() { return true; }

    uint64 Size() const { return numBytes; }
};


// Forward declares
template<typename TSerializer, typename TString>
void SerializeItem(TSerializer& serializer, std::basic_string<TString>& str);

// Trampoline functions
template<typename TSerializer, typename TValue>
void SerializeItem(TSerializer& serializer, TValue& val)
{
    val.Serialize(serializer);
}

// Specialized serializers
template<typename TSerializer>
void SerializeItem(TSerializer& serializer, uint32& val)
{
    serializer.SerializeItem(val);
}

template<typename TSerializer>
void SerializeItem(TSerializer& serializer, int32& val)
{
    serializer.SerializeItem(val);
}

template<typename TSerializer>
void SerializeItem(TSerializer& serializer, uint64& val)
{
    serializer.SerializeItem(val);
}

template<typename TSerializer>
void SerializeItem(TSerializer& serializer, int64& val)
{
    serializer.SerializeItem(val);
}

template<typename TSerializer>
void SerializeItem(TSerializer& serializer, float& val)
{
    serializer.SerializeItem(val);
}

template<typename TSerializer>
void SerializeItem(TSerializer& serializer, double& val)
{
    serializer.SerializeItem(val);
}

template<typename TSerializer>
void SerializeItem(TSerializer& serializer, Float2& val)
{
    serializer.SerializeItem(val.x);
    serializer.SerializeItem(val.y);
}

template<typename TSerializer>
void SerializeItem(TSerializer& serializer, Float3& val)
{
    serializer.SerializeItem(val.x);
    serializer.SerializeItem(val.y);
    serializer.SerializeItem(val.z);
}

template<typename TSerializer>
void SerializeItem(TSerializer& serializer, Float4& val)
{
    serializer.SerializeItem(val.x);
    serializer.SerializeItem(val.y);
    serializer.SerializeItem(val.z);
    serializer.SerializeItem(val.w);
}

template<typename TSerializer>
void SerializeItem(TSerializer& serializer, Quaternion& val)
{
    serializer.SerializeItem(val.x);
    serializer.SerializeItem(val.y);
    serializer.SerializeItem(val.z);
    serializer.SerializeItem(val.w);
}

template<typename TSerializer>
void SerializeData(TSerializer& serializer, void* data, uint64 size)
{
    serializer.SerializeData(size, data);
}

template<typename TSerializer, typename TValue>
void SerializeArray(TSerializer& serializer, TValue* array, uint64 numElements)
{
    for(uint64 i = 0; i < numElements; ++i)
        SerializeItem(serializer, array[i]);
}

template<typename TSerializer, typename TValue>
void SerializeRawArray(TSerializer& serializer, TValue* array, uint64 numElements)
{
    SerializeData(serializer, array, sizeof(TValue) * numElements);
}

template<typename TSerializer, typename TVector>
void SerializeItem(TSerializer& serializer, std::vector<TVector>& vec)
{
    uint64 numElements = vec.size();
    SerializeItem(serializer, numElements);
    if(vec.size() != numElements)
        vec.resize(numElements);

    if(numElements == 0)
        return;

    SerializeArray(serializer, vec.data(), numElements);
}

template<typename TSerializer, typename TVector>
void SerializeRawVector(TSerializer& serializer, std::vector<TVector>& vec)
{
    uint64 numElements = vec.size();
    SerializeItem(serializer, numElements);
    if(vec.size() != numElements)
        vec.resize(numElements);

    if(numElements == 0)
        return;

    SerializeRawArray(serializer, vec.data(), numElements);
}

template<typename TSerializer, typename TString>
void SerializeItem(TSerializer& serializer, std::basic_string<TString>& str)
{
    uint64 numChars = str.length();
    SerializeItem(serializer, numChars);
    if(str.length() != numChars)
        str.resize(numChars);

    if(numChars == 0)
        return;

    SerializeRawArray(serializer, const_cast<TString*>(str.data()), numChars);
}

// Convenience functions for file serialization
template<typename T>
void SerializeFromFile(const wchar* filePath, T& item)
{
    FileReadSerializer serializer(filePath);
    SerializeItem(serializer, item);
}

template<typename T>
void SerializeToFile(const wchar* filePath, const T& item)
{
    FileWriteSerializer serializer(filePath);
    SerializeItem(serializer, item);
}

}