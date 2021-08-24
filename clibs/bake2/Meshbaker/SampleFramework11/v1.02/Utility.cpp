//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "Utility.h"
#include "Exceptions.h"

namespace SampleFramework11
{

void PrintStringW(const wchar* format, ...)
{
    va_list args;
    va_start(args, format);
    vwprintf_s(format, args);
    wprintf_s(L"\n");
}

void PrintString(const char* format, ...)
{
    va_list args;
    va_start(args, format);
    vprintf_s(format, args);
    printf_s("\n");
}

std::wstring MakeString(const wchar* format, ...)
{
    wchar buffer[1024] = { 0 };
    va_list args;
    va_start(args, format);
    vswprintf_s(buffer, ArraySize_(buffer), format, args);
    return std::wstring(buffer);
}

std::string MakeAnsiString(const char* format, ...)
{
    char buffer[1024] = { 0 };
    va_list args;
    va_start(args, format);
    vsprintf_s(buffer, ArraySize_(buffer), format, args);
    return std::string(buffer);
}

std::wstring SampleFrameworkDir()
{
    return std::wstring(SampleFrameworkDir_);
}

// Converts from cartesian to barycentric coordinates
XMFLOAT3 CartesianToBarycentric(float x, float y, const XMFLOAT2& pos1, const XMFLOAT2& pos2, const XMFLOAT2& pos3)
{
    float r1 = (pos2.y - pos3.y) * (x - pos3.x) + (pos3.x - pos2.x) * (y - pos3.y);
    r1 /= (pos2.y - pos3.y) * (pos1.x - pos3.x) + (pos3.x - pos2.x) * (pos1.y - pos3.y);

    float r2 = (pos3.y - pos1.y) * (x - pos3.x) + (pos1.x - pos3.x) * (y - pos3.y);
    r2 /= (pos3.y - pos1.y) * (pos2.x - pos3.x) + (pos1.x - pos3.x) * (pos2.y - pos3.y);

    float r3 = 1.0f - r1 - r2;

    return XMFLOAT3(r1, r2, r3);
}

// Converts from barycentric to cartesian coordinates
XMFLOAT2 BarycentricToCartesian(const XMFLOAT3& r, const XMFLOAT2& pos1, const XMFLOAT2& pos2, const XMFLOAT2& pos3)
{
    float x = r.x * pos1.x + r.y * pos2.x + r.z * pos3.x;
    float y = r.x * pos1.y + r.y * pos2.y + r.z * pos3.y;

    return XMFLOAT2(x, y);
}

// Converts from barycentric to cartesian coordinates
XMVECTOR BarycentricToCartesian(const XMFLOAT3& r, FXMVECTOR pos1, FXMVECTOR pos2, FXMVECTOR pos3)
{
    XMVECTOR rvec;
    rvec = XMVectorScale(pos1, r.x);
    rvec += XMVectorScale(pos2, r.y);
    rvec += XMVectorScale(pos3, r.z);

    return rvec;
}

// Returns true if the given barycentric coordinate is in the triangle
BOOL PointIsInTriangle(const XMFLOAT3& r, float epsilon)
{
    float minr = 0.0f - epsilon;
    float maxr = 1.0f + epsilon;

    if(r.x < minr || r.x > maxr)
        return false;

    if(r.y < minr || r.y > maxr)
        return false;

    if(r.z < minr || r.z > maxr)
        return false;

    float rsum = r.x + r.y + r.z;
    return rsum >= minr && rsum <= maxr;
}

// Computes a compute shader dispatch size given a thread group size, and number of elements to process
uint32 DispatchSize(uint32 tgSize, uint32 numElements)
{
    uint32 dispatchSize = numElements / tgSize;
    dispatchSize += numElements % tgSize > 0 ? 1 : 0;
    return dispatchSize;
}

void SetCSInputs(ID3D11DeviceContext* context, ID3D11ShaderResourceView* srv0, ID3D11ShaderResourceView* srv1,
                    ID3D11ShaderResourceView* srv2, ID3D11ShaderResourceView* srv3)
{
    ID3D11ShaderResourceView* srvs[4] = { srv0, srv1, srv2, srv3 };
    context->CSSetShaderResources(0, 4, srvs);
}

void ClearCSInputs(ID3D11DeviceContext* context)
{
    SetCSInputs(context, nullptr, nullptr, nullptr, nullptr);
}

void SetCSOutputs(ID3D11DeviceContext* context, ID3D11UnorderedAccessView* uav0, ID3D11UnorderedAccessView* uav1,
                    ID3D11UnorderedAccessView* uav2, ID3D11UnorderedAccessView* uav3, ID3D11UnorderedAccessView* uav4,
                    ID3D11UnorderedAccessView* uav5)
{
    ID3D11UnorderedAccessView* uavs[6] = { uav0, uav1, uav2, uav3, uav4, uav5 };
    context->CSSetUnorderedAccessViews(0, 6, uavs, nullptr);
}

void ClearCSOutputs(ID3D11DeviceContext* context)
{
    SetCSOutputs(context, nullptr, nullptr, nullptr, nullptr);
}

void SetCSSamplers(ID3D11DeviceContext* context, ID3D11SamplerState* sampler0, ID3D11SamplerState* sampler1,
                    ID3D11SamplerState* sampler2, ID3D11SamplerState* sampler3)
{
    ID3D11SamplerState* samplers[4] = { sampler0, sampler1, sampler2, sampler3 };
    context->CSSetSamplers(0, 4, samplers);
}

void SetCSShader(ID3D11DeviceContext* context, ID3D11ComputeShader* shader)
{
    context->CSSetShader(shader, nullptr, 0);
}

void SetCSConstants(ID3D11DeviceContext* context, ID3D11Buffer* constantBuffer, uint32 slot)
{
    ID3D11Buffer* constants[1] = { constantBuffer };
    context->CSSetConstantBuffers(slot, 1, constants);
}

}