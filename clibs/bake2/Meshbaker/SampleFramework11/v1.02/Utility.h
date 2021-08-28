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
#include "InterfacePointers.h"
#include "SF11_Math.h"
#include "Assert_.h"

namespace SampleFramework11
{

// Returns a size suitable for creating a constant buffer, by rounding up
// to the next multiple of 16
inline UINT CBSize(UINT size)
{
    return ((size + 15) / 16) * 16;
}

// Converts an ANSI string to a std::wstring
inline std::wstring AnsiToWString(const char* ansiString)
{
    wchar buffer[512];
    Win32Call(MultiByteToWideChar(CP_ACP, 0, ansiString, -1, buffer, 512));
    return std::wstring(buffer);
}

inline std::string WStringToAnsi(const wchar* wideString)
{
    char buffer[512];
    Win32Call(WideCharToMultiByte(CP_ACP, 0, wideString, -1, buffer, 612, NULL, NULL));
    return std::string(buffer);
}

// Splits up a string using a delimiter
inline void Split(const std::wstring& str, std::vector<std::wstring>& parts, const std::wstring& delimiters = L" ")
{
    // Skip delimiters at beginning
    std::wstring::size_type lastPos = str.find_first_not_of(delimiters, 0);

    // Find first "non-delimiter"
    std::wstring::size_type pos = str.find_first_of(delimiters, lastPos);

    while (std::wstring::npos != pos || std::wstring::npos != lastPos)
    {
        // Found a token, add it to the vector
        parts.push_back(str.substr(lastPos, pos - lastPos));

        // Skip delimiters.  Note the "not_of"
        lastPos = str.find_first_not_of(delimiters, pos);

        // Find next "non-delimiter"
        pos = str.find_first_of(delimiters, lastPos);
    }
}

// Splits up a string using a delimiter
inline std::vector<std::wstring> Split(const std::wstring& str, const std::wstring& delimiters = L" ")
{
    std::vector<std::wstring> parts;
    Split(str, parts, delimiters);
    return parts;
}

// Parses a string into a number
template<typename T> inline T Parse(const std::wstring& str)
{
    std::wistringstream stream(str);
    wchar_t c;
    T x;
    if(!(str >> x) || stream.get(c))
        throw Exception(L"Can't parse string \"" + str + L"\"");
    return x;
}

// Converts a number to a string
template<typename T> inline std::wstring ToString(const T& val)
{
    std::wostringstream stream;
    if(!(stream << val))
        throw Exception(L"Error converting value to string");
    return stream.str();
}

// Converts a number to an ansi string
template<typename T> inline std::string ToAnsiString(const T& val)
{
    std::ostringstream stream;
    if(!(stream << val))
        throw Exception(L"Error converting value to string");
    return stream.str();
}

void PrintStringW(const wchar* format, ...);
void PrintString(const char* format, ...);

std::wstring MakeString(const wchar* format, ...);
std::string MakeAnsiString(const char* format, ...);

std::wstring SampleFrameworkDir();
std::wstring ContentDir();

// Outputs a string to the debugger output and stdout
inline void DebugPrint(const std::wstring& str)
{
    std::wstring output = str + L"\n";
    OutputDebugStringW(output.c_str());
    std::printf("%ls", output.c_str());
}

// Returns the number of mip levels given a texture size
inline UINT NumMipLevels(UINT width, UINT height)
{
    UINT numMips = 0;
    UINT size = std::max(width, height);
    while (1U << numMips <= size)
        ++numMips;

    if (1U << numMips < size)
        ++numMips;

    return numMips;
}

// Gets an index from an index buffer
inline uint32 GetIndex(const void* indices, uint32 idx, uint32 indexSize)
{
    if(indexSize == 2)
        return reinterpret_cast<const uint16*>(indices)[idx];
    else
        return reinterpret_cast<const uint32*>(indices)[idx];
}

// Sets the viewport for a given render target size
inline void SetViewport(ID3D11DeviceContext* context, uint32 rtWidth, uint32 rtHeight)
{
    D3D11_VIEWPORT viewport;
    viewport.Width = static_cast<float>(rtWidth);
    viewport.Height = static_cast<float>(rtHeight);
    viewport.MinDepth = 0.0f;
    viewport.MaxDepth = 1.0f;
    viewport.TopLeftX = 0.0f;
    viewport.TopLeftY = 0.0f;

    context->RSSetViewports(1, &viewport);
}

// Copies a portion of a buffer to another buffer
inline void CopyBufferRegion(ID3D11DeviceContext* context, ID3D11Buffer* dstBuffer, ID3D11Buffer* srcBuffer,
                             uint32 dstOffset, uint32 srcOffset, uint32 srcSize)
{
    D3D11_BOX srcBox;
    srcBox.left = srcOffset;
    srcBox.right = srcOffset + srcSize;
    srcBox.top = 0;
    srcBox.bottom = 1;
    srcBox.front = 0;
    srcBox.back = 1;
    context->CopySubresourceRegion(dstBuffer, 0, dstOffset, 0, 0, srcBuffer, 0, &srcBox);
}

template<typename T, uint64 N>
uint64 ArraySize(T(&)[N])
{
    return N;
}

#define ArraySize_(x) ((sizeof(x) / sizeof(0[x])) / ((size_t)(!(sizeof(x) % sizeof(0[x])))))

// Barycentric coordinate functions
XMFLOAT3 CartesianToBarycentric(float x, float y, const XMFLOAT2& pos1, const XMFLOAT2& pos2, const XMFLOAT2& pos3);
XMFLOAT2 BarycentricToCartesian(const XMFLOAT3& r, const XMFLOAT2& pos1, const XMFLOAT2& pos2, const XMFLOAT2& pos3);
XMVECTOR BarycentricToCartesian(const XMFLOAT3& r, FXMVECTOR pos1, FXMVECTOR pos2, FXMVECTOR pos3);
BOOL PointIsInTriangle(const XMFLOAT3& r, float epsilon = 0.0f);

// Compute shader helpers
uint32 DispatchSize(uint32 tgSize, uint32 numElements);
void SetCSInputs(ID3D11DeviceContext* context, ID3D11ShaderResourceView* srv0, ID3D11ShaderResourceView* srv1 = NULL,
                    ID3D11ShaderResourceView* srv2 = NULL, ID3D11ShaderResourceView* srv3 = NULL);
void ClearCSInputs(ID3D11DeviceContext* context);
void SetCSOutputs(ID3D11DeviceContext* context, ID3D11UnorderedAccessView* uav0, ID3D11UnorderedAccessView* uav1 = NULL,
                    ID3D11UnorderedAccessView* uav2 = NULL, ID3D11UnorderedAccessView* uav3 = NULL,
                    ID3D11UnorderedAccessView* uav4 = NULL, ID3D11UnorderedAccessView* uav5 = NULL);
void ClearCSOutputs(ID3D11DeviceContext* context);
void SetCSSamplers(ID3D11DeviceContext* context, ID3D11SamplerState* sampler0, ID3D11SamplerState* sampler1 = NULL,
                    ID3D11SamplerState* sampler2 = NULL, ID3D11SamplerState* sampler3 = NULL);
void SetCSShader(ID3D11DeviceContext* context, ID3D11ComputeShader* shader);
void SetCSConstants(ID3D11DeviceContext* context, ID3D11Buffer* constantBuffer, uint32 slot);

}