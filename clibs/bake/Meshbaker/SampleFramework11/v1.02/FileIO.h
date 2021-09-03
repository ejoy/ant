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
#include "Utility.h"

namespace SampleFramework11
{

// Utility functions
bool FileExists(const wchar* filePath);
bool DirectoryExists(const wchar* dirPath);
std::wstring GetDirectoryFromFilePath(const wchar* filePath);
std::wstring GetFileName(const wchar* filePath);
std::wstring GetFileNameWithoutExtension(const wchar* filePath);
std::wstring GetFilePathWithoutExtension(const wchar* filePath);
std::wstring GetFileExtension(const wchar* filePath);
uint64 GetFileTimestamp(const wchar* filePath);

std::string ReadFileAsString(const wchar* filePath);
void WriteStringAsFile(const wchar* filePath, const std::string& data);

enum class FileOpenMode
{
    Read = 0,
    Write = 1,
};

class File
{

private:

    HANDLE fileHandle;
    FileOpenMode openMode;

public:

    // Lifetime
    File();
    File(const wchar* filePath, FileOpenMode openMode);
    ~File();

    // Explicit Open and close
    void Open(const wchar* filePath, FileOpenMode openMode);
    void Close();

    // I/O
    void Read(uint64 size, void* data) const;
    void Write(uint64 size, const void* data) const;

    template<typename T> void Read(T& data) const;
    template<typename T> void Write(const T& data) const;

    // Accessors
    uint64 Size() const;
};

// == File ========================================================================================

template<typename T> void File::Read(T& data) const
{
    Read(sizeof(T), &data);
}

template<typename T> void File::Write(const T& data) const
{
    Write(sizeof(T), &data);
}

// Templated helper functions

// Reads a POD type from a file
template<typename T> void ReadFromFile(const wchar* fileName, T& val)
{
    File file(fileName, File::OpenRead);
    file.Read(val);
}

// Writes a POD type to a file
template<typename T> void WriteToFile(const wchar* fileName, const T& val)
{
    File file(fileName, File::OpenWrite);
    file.Write(val);
}

}