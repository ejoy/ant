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
#include "..\\Assert_.h"

namespace SampleFramework11
{

class CompileOptions
{
public:

    // constants
    static const uint32 MaxDefines = 16;
    static const uint32 BufferSize = 1024;

    CompileOptions();

    void Add(const std::string& name, uint32 value);
    void Reset();

    void MakeDefines(D3D_SHADER_MACRO defines[MaxDefines + 1]) const;

private:

    uint32 nameOffsets[MaxDefines];
    uint32 defineOffsets[MaxDefines];
    char buffer[BufferSize];
    uint32 numDefines;
    uint32 bufferIdx;
};

class CompiledShader
{

public:

    ID3D11DeviceChildPtr ShaderPtr;
    std::wstring FilePath;
    std::string FunctionName;
    std::string Profile;
    CompileOptions CompileOpts;
    bool ForceOptimization;
    ID3DBlobPtr ByteCode;
    const type_info* Type;

    CompiledShader(const wchar* filePath, const char* functionName,
                   const char* profile, const CompileOptions& compileOptions,
                   bool forceOptimization, const type_info& type) : FilePath(filePath),
                                            FunctionName(functionName),
                                            Profile(profile),
                                            CompileOpts(compileOptions),
                                            ForceOptimization(forceOptimization),
                                            Type(&type)
    {
    }
};

template<typename T> class CompiledShaderT : public CompiledShader
{

public:

    CompiledShaderT(const wchar* filePath, const char* functionName,
                    const char* profile, const CompileOptions& compileOptions,
                    bool forceOptimization) : CompiledShader(filePath, functionName, profile,
                                                            compileOptions, forceOptimization, typeid(T))
    {
    }

    T* Shader() const
    {
        Assert_(ShaderPtr != nullptr);
        Assert_(*Type == typeid(T));
        return reinterpret_cast<T*>(ShaderPtr.GetInterfacePtr());
    }
};

typedef CompiledShaderT<ID3D11VertexShader> CompiledVertexShader;
typedef CompiledShaderT<ID3D11HullShader> CompiledHullShader;
typedef CompiledShaderT<ID3D11DomainShader> CompiledDomainShader;
typedef CompiledShaderT<ID3D11GeometryShader> CompiledGeometryShader;
typedef CompiledShaderT<ID3D11PixelShader> CompiledPixelShader;
typedef CompiledShaderT<ID3D11ComputeShader> CompiledComputeShader;

template<typename T> class CompiledShaderPtr
{
public:

    CompiledShaderPtr() : ptr(nullptr)
    {
    }

    CompiledShaderPtr(const CompiledShaderT<T>* ptr_) : ptr(ptr_)
    {
    }

    const CompiledShaderT<T>* operator->() const
    {
        Assert_(ptr != nullptr);
        return ptr;
    }

    const CompiledShaderT<T>& operator*() const
    {
        Assert_(ptr != nullptr);
        return *ptr;
    }

    operator T*() const
    {
        Assert_(ptr != nullptr);
        return ptr->Shader();
    }

    bool Valid() const
    {
        return ptr != nullptr;
    }

private:

    const CompiledShaderT<T>* ptr;
};

typedef CompiledShaderPtr<ID3D11VertexShader> VertexShaderPtr;
typedef CompiledShaderPtr<ID3D11HullShader> HullShaderPtr;
typedef CompiledShaderPtr<ID3D11DomainShader> DomainShaderPtr;
typedef CompiledShaderPtr<ID3D11GeometryShader> GeometryShaderPtr;
typedef CompiledShaderPtr<ID3D11PixelShader> PixelShaderPtr;
typedef CompiledShaderPtr<ID3D11ComputeShader> ComputeShaderPtr;

// Compiles a shader from file and creates the appropriate shader instance
VertexShaderPtr CompileVSFromFile(ID3D11Device* device,
                                  const wchar* path,
                                  const char* functionName = "VS",
                                  const char* profile = "vs_5_0",
                                  const CompileOptions& compileOpts = CompileOptions(),
                                  bool forceOptimization = false);

PixelShaderPtr CompilePSFromFile(ID3D11Device* device,
                                 const wchar* path,
                                 const char* functionName = "PS",
                                 const char* profile = "ps_5_0",
                                 const CompileOptions& compileOpts = CompileOptions(),
                                 bool forceOptimization = false);

GeometryShaderPtr CompileGSFromFile(ID3D11Device* device,
                                    const wchar* path,
                                    const char* functionName = "GS",
                                    const char* profile = "gs_5_0",
                                    const CompileOptions& compileOpts = CompileOptions(),
                                    bool forceOptimization = false);

HullShaderPtr CompileHSFromFile(ID3D11Device* device,
                                const wchar* path,
                                const char* functionName = "HS",
                                const char* profile = "hs_5_0",
                                const CompileOptions& compileOpts = CompileOptions(),
                                bool forceOptimization = false);

DomainShaderPtr CompileDSFromFile(ID3D11Device* device,
                                  const wchar* path,
                                  const char* functionName = "DS",
                                  const char* profile = "ds_5_0",
                                  const CompileOptions& compileOpts = CompileOptions(),
                                  bool forceOptimization = false);

ComputeShaderPtr CompileCSFromFile(ID3D11Device* device,
                                   const wchar* path,
                                   const char* functionName = "CS",
                                   const char* profile = "cs_5_0",
                                   const CompileOptions& compileOpts = CompileOptions(),
                                   bool forceOptimization = false);

void UpdateShaders(ID3D11Device* device);
void ShutdownShaders();

}
