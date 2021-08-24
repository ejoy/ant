//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "FileIO.h"

namespace SampleFramework11
{

// Returns true if a file exits
bool FileExists(const wchar* filePath)
{
    if(filePath == NULL)
        return false;

    DWORD fileAttr = GetFileAttributes(filePath);
    if (fileAttr == INVALID_FILE_ATTRIBUTES)
        return false;

    return true;
}

// Retursn true if a directory exists
bool DirectoryExists(const wchar* dirPath)
{
    if(dirPath == NULL)
        return false;

    DWORD fileAttr = GetFileAttributes(dirPath);
    return (fileAttr != INVALID_FILE_ATTRIBUTES && (fileAttr & FILE_ATTRIBUTE_DIRECTORY));
}


// Returns the directory containing a file
std::wstring GetDirectoryFromFilePath(const wchar* filePath_)
{
    Assert_(filePath_);

    std::wstring filePath(filePath_);
    size_t idx = filePath.rfind(L'\\');
    if(idx != std::wstring::npos)
        return filePath.substr(0, idx + 1);
    else
        return std::wstring(L"");
}

// Returns the name of the file given the path (extension included)
std::wstring GetFileName(const wchar* filePath_)
{
    Assert_(filePath_);

    std::wstring filePath(filePath_);
    size_t idx = filePath.rfind(L'\\');
    if(idx != std::wstring::npos && idx < filePath.length() - 1)
        return filePath.substr(idx + 1);
    else
    {
        idx = filePath.rfind(L'/');
        if(idx != std::wstring::npos && idx < filePath.length() - 1)
            return filePath.substr(idx + 1);
        else
            return filePath;
    }
}

// Returns the name of the file given the path, minus the extension
std::wstring GetFileNameWithoutExtension(const wchar* filePath)
{
    std::wstring fileName = GetFileName(filePath);
    return GetFilePathWithoutExtension(fileName.c_str());
}

// Returns the given file path, minus the extension
std::wstring GetFilePathWithoutExtension(const wchar* filePath_)
{
    Assert_(filePath_);

    std::wstring filePath(filePath_);
    size_t idx = filePath.rfind(L'.');
    if (idx != std::wstring::npos)
        return filePath.substr(0, idx);
    else
        return std::wstring(L"");
}

// Returns the extension of the file path
std::wstring GetFileExtension(const wchar* filePath_)
{
    Assert_(filePath_);

    std::wstring filePath(filePath_);
    size_t idx = filePath.rfind(L'.');
    if (idx != std::wstring::npos)
        return filePath.substr(idx + 1, filePath.length() - idx - 1);
    else
        return std::wstring(L"");
}

// Gets the last written timestamp of the file
uint64 GetFileTimestamp(const wchar* filePath)
{
    Assert_(filePath);

    WIN32_FILE_ATTRIBUTE_DATA attributes;
    Win32Call(GetFileAttributesEx(filePath, GetFileExInfoStandard, &attributes));
    return attributes.ftLastWriteTime.dwLowDateTime | (uint64(attributes.ftLastWriteTime.dwHighDateTime) << 32);
}

// Returns the contents of a file as a string
std::string ReadFileAsString(const wchar* filePath)
{
    File file(filePath, FileOpenMode::Read);
    uint64 fileSize = file.Size();

    std::string fileContents;
    fileContents.resize(size_t(fileSize), 0);
    file.Read(fileSize, &fileContents[0]);

    return fileContents;
}

// Writes the contents of a string to a file
void WriteStringAsFile(const wchar* filePath, const std::string& data)
{
    File file(filePath, FileOpenMode::Write);
    file.Write(data.length(), data.c_str());
}

// == File ========================================================================================

File::File() : fileHandle(INVALID_HANDLE_VALUE), openMode(FileOpenMode::Read)
{
}

File::File(const wchar* filePath, FileOpenMode openMode) : fileHandle(INVALID_HANDLE_VALUE),
                                                           openMode(FileOpenMode::Read)
{
    Open(filePath, openMode);
}

File::~File()
{
    Close();
    Assert_(fileHandle == INVALID_HANDLE_VALUE);
}

void File::Open(const wchar* filePath, FileOpenMode openMode_)
{
    Assert_(fileHandle == INVALID_HANDLE_VALUE);
    openMode = openMode_;

    if(openMode == FileOpenMode::Read)
    {
        Assert_(FileExists(filePath));

        // Open the file
        fileHandle = CreateFile(filePath, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
        if(fileHandle == INVALID_HANDLE_VALUE)
        {
            std::wstring errPrefix = std::wstring(L"Failed to open file ") + filePath + L":\n";
            Assert_(false);
            throw Win32Exception(GetLastError(), errPrefix.c_str());
        }
    }
    else
    {
        // If the exists, delete it
        if(FileExists(filePath))
            Win32Call(DeleteFile(filePath));

        // Create the file
        fileHandle = CreateFile(filePath, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
        if(fileHandle == INVALID_HANDLE_VALUE)
        {
            std::wstring errPrefix = std::wstring(L"Failed to open file ") + filePath + L":\n";
            Assert_(false);
            throw Win32Exception(GetLastError(), errPrefix.c_str());
        }
    }
}

void File::Close()
{
    if(fileHandle == INVALID_HANDLE_VALUE)
        return;

    // Close the file
    Win32Call(CloseHandle(fileHandle));

    fileHandle = INVALID_HANDLE_VALUE;
}

void File::Read(uint64 size, void* data) const
{
    Assert_(fileHandle != INVALID_HANDLE_VALUE);
    Assert_(openMode == FileOpenMode::Read);

    DWORD bytesRead = 0;
    Win32Call(ReadFile(fileHandle, data, static_cast<DWORD>(size), &bytesRead, NULL));
}

void File::Write(uint64 size, const void* data) const
{
    Assert_(fileHandle != INVALID_HANDLE_VALUE);
    Assert_(openMode == FileOpenMode::Write);

    DWORD bytesWritten = 0;
    Win32Call(WriteFile(fileHandle, data, static_cast<DWORD>(size), &bytesWritten, NULL));
}

uint64 File::Size() const
{
    Assert_(fileHandle != INVALID_HANDLE_VALUE);

    LARGE_INTEGER fileSize;
    Win32Call(GetFileSizeEx(fileHandle, &fileSize));

    return fileSize.QuadPart;
}

}