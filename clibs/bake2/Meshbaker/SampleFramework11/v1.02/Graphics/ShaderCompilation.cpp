//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "ShaderCompilation.h"

#include "..\\Utility.h"
#include "..\\Exceptions.h"
#include "..\\InterfacePointers.h"
#include "..\\FileIO.h"
#include "..\\MurmurHash.h"

using std::vector;
using std::wstring;
using std::string;
using std::map;

namespace SampleFramework11
{

static string GetExpandedShaderCode(const wchar* path, vector<wstring>& filePaths)
{
    for(uint64 i = 0; i < filePaths.size(); ++i)
        if(filePaths[i] == path)
            return string();

    filePaths.push_back(path);

    string fileContents = ReadFileAsString(path);

    // Look for includes
    size_t lineStart = 0;
    size_t lineEnd = std::string::npos;
    while(true)
    {
        size_t lineEnd = fileContents.find('\n', lineStart);
        size_t lineLength = 0;
        if(lineEnd == string::npos)
            lineLength = string::npos;
        else
            lineLength = lineEnd - lineStart;

        string line = fileContents.substr(lineStart, lineLength);
        if(line.find("#include") == 0)
        {
            wstring fullIncludePath;
            size_t startQuote = line.find('\"');
            if(startQuote != -1)
            {
                size_t endQuote = line.find('\"', startQuote + 1);
                string includePath = line.substr(startQuote + 1, endQuote - startQuote - 1);
                fullIncludePath = AnsiToWString(includePath.c_str());
            }
            else
            {
                startQuote = line.find('<');
                if(startQuote == -1)
                    throw Exception(L"Malformed include statement: \"" + AnsiToWString(line.c_str()) + L"\" in file " + path);
                size_t endQuote = line.find('>', startQuote + 1);
                string includePath = line.substr(startQuote + 1, endQuote - startQuote - 1);
                fullIncludePath = SampleFrameworkDir() + L"Shaders\\" + AnsiToWString(includePath.c_str());
            }

            if(FileExists(fullIncludePath.c_str()) == false)
                throw Exception(L"Couldn't find #included file \"" + fullIncludePath + L"\" in file " + path);

            string includeCode = GetExpandedShaderCode(fullIncludePath.c_str(), filePaths);
            fileContents.insert(lineEnd + 1, includeCode);
            lineEnd += includeCode.length();
        }

        if(lineEnd == string::npos)
            break;

        lineStart = lineEnd + 1;
    }

    return fileContents;
}

static const wstring baseCacheDir = L"ShaderCache\\";

#if _DEBUG
    static const wstring cacheSubDir = L"Debug\\";
#else
    static const std::wstring cacheSubDir = L"Release\\";
#endif

static const wstring cacheDir = baseCacheDir + cacheSubDir;

static string MakeDefinesString(const D3D_SHADER_MACRO* defines)
{
    string definesString;
    while(defines && defines->Name != nullptr && defines != nullptr)
    {
        if(definesString.length() > 0)
            definesString += "|";
        definesString += defines->Name;
        definesString += "=";
        definesString += defines->Definition;
        ++defines;
    }

    return definesString;
}

static wstring MakeShaderCacheName(const std::string& shaderCode, const char* functionName,
                                   const char* profile, const D3D_SHADER_MACRO* defines)
{
    string hashString = shaderCode;
    hashString += "\n";
    hashString += functionName;
    hashString += "\n";
    hashString += profile;
    hashString += "\n";

    hashString += MakeDefinesString(defines);

    Hash codeHash = GenerateHash(hashString.data(), int(hashString.length()), 0);

    return cacheDir + codeHash.ToString() + L".cache";
}

class FrameworkInclude : public ID3DInclude
{
    HRESULT Open(D3D_INCLUDE_TYPE IncludeType, LPCSTR pFileName, LPCVOID pParentData, LPCVOID* ppData, UINT* pBytes) override
    {
        std::wstring filePath;
        if(IncludeType == D3D_INCLUDE_LOCAL)
            filePath = AnsiToWString(pFileName);
        else if(IncludeType == D3D_INCLUDE_SYSTEM)
            filePath = SampleFrameworkDir() + L"Shaders\\" + AnsiToWString(pFileName);
        else
            return E_FAIL;

        if(FileExists(filePath.c_str()) == false)
            return E_FAIL;
        File file(filePath.c_str(), FileOpenMode::Read);
        *pBytes = UINT(file.Size());
        uint8* data = reinterpret_cast<uint8*>(std::malloc(*pBytes));
        file.Read(*pBytes, data);
        *ppData = data;
        return S_OK;
    }

    HRESULT Close(LPCVOID pData) override
    {
        std::free(const_cast<void*>(pData));
        return S_OK;
    }
};

static ID3DBlob* CompileShader(const wchar* path, const char* functionName, const char* profile,
                              const D3D_SHADER_MACRO* defines, bool forceOptimization,
                              vector<wstring>& filePaths)
{
    if(FileExists(path) == false)
    {
        Assert_(false);
        throw Exception(L"Shader file " + std::wstring(path) + L" does not exist");
    }

    // Make a hash off the expanded shader code
    string shaderCode = GetExpandedShaderCode(path, filePaths);
    wstring cacheName = MakeShaderCacheName(shaderCode, functionName, profile, defines);

    if(FileExists(cacheName.c_str()))
    {
        File cacheFile(cacheName.c_str(), FileOpenMode::Read);

        const uint64 shaderSize = cacheFile.Size();
        vector<uint8> compressedShader;
        compressedShader.resize(shaderSize);
        cacheFile.Read(shaderSize, compressedShader.data());

        ID3DBlob* decompressedShader[1] = { nullptr };
        uint32 indices[1] = { 0 };
        DXCall(D3DDecompressShaders(compressedShader.data(), shaderSize, 1, 0,
                                    indices, 0, decompressedShader, nullptr));

        return decompressedShader[0];
    }

    std::printf("Compiling shader %s %s %s\n", WStringToAnsi(GetFileName(path).c_str()).c_str(),
                profile, MakeDefinesString(defines).c_str());

    // Loop until we succeed, or an exception is thrown
    while(true)
    {
        UINT flags = D3DCOMPILE_WARNINGS_ARE_ERRORS;
        #ifdef _DEBUG
            flags |= D3DCOMPILE_DEBUG;
            if(forceOptimization == false)
                flags |= D3DCOMPILE_SKIP_OPTIMIZATION;
        #endif

        ID3DBlob* compiledShader;
        ID3DBlobPtr errorMessages;
        FrameworkInclude include;
        HRESULT hr = D3DCompileFromFile(path, defines, &include, functionName,
                                        profile, flags, 0, &compiledShader, &errorMessages);

        if(FAILED(hr))
        {
            if(errorMessages)
            {
                wchar message[1024] = { 0 };
                char* blobdata = reinterpret_cast<char*>(errorMessages->GetBufferPointer());

                MultiByteToWideChar(CP_ACP, 0, blobdata, static_cast<int>(errorMessages->GetBufferSize()), message, 1024);
                std::wstring fullMessage = L"Error compiling shader file \"";
                fullMessage += path;
                fullMessage += L"\" - ";
                fullMessage += message;

                // Pop up a message box allowing user to retry compilation
                int retVal = MessageBoxW(nullptr, fullMessage.c_str(), L"Shader Compilation Error", MB_RETRYCANCEL);
                if(retVal != IDRETRY)
                    throw DXException(hr, fullMessage.c_str());
            }
            else
            {
                Assert_(false);
                throw DXException(hr);
            }
        }
        else
        {
            // Compress the shader
            D3D_SHADER_DATA shaderData;
            shaderData.pBytecode = compiledShader->GetBufferPointer();
            shaderData.BytecodeLength = compiledShader->GetBufferSize();
            ID3DBlobPtr compressedShader;
            DXCall(D3DCompressShaders(1, &shaderData, D3D_COMPRESS_SHADER_KEEP_ALL_PARTS, &compressedShader));

            // Create the cache directory if it doesn't exist
            if(DirectoryExists(baseCacheDir.c_str()) == false)
                Win32Call(CreateDirectory(baseCacheDir.c_str(), nullptr));

            if(DirectoryExists(cacheDir.c_str()) == false)
                Win32Call(CreateDirectory(cacheDir.c_str(), nullptr));

            File cacheFile(cacheName.c_str(), FileOpenMode::Write);

            // Write the compiled shader to disk
            uint64 shaderSize = compressedShader->GetBufferSize();
            cacheFile.Write(shaderSize, compressedShader->GetBufferPointer());

            return compiledShader;
        }
    }
}

struct ShaderFile
{
    wstring FilePath;
    uint64 TimeStamp;
    vector<CompiledShader*> Shaders;

    ShaderFile(const wstring& filePath) : TimeStamp(0), FilePath(filePath)
    {
    }
};

vector<ShaderFile*> ShaderFiles;
vector<CompiledShader*> CompiledShaders;

template<typename T> ID3D11DeviceChild* CreateShader(ID3D11Device* device, ID3DBlob* byteCode)
{
    if(typeid(T) == typeid(ID3D11VertexShader))
    {
        ID3D11VertexShader* shader = nullptr;
        DXCall(device->CreateVertexShader(byteCode->GetBufferPointer(), byteCode->GetBufferSize(),
                                          nullptr, &shader));
        return shader;
    }
    else if(typeid(T) == typeid(ID3D11HullShader))
    {
        ID3D11HullShader* shader = nullptr;
        DXCall(device->CreateHullShader(byteCode->GetBufferPointer(), byteCode->GetBufferSize(),
                                          nullptr, &shader));
        return shader;
    }
    else if(typeid(T) == typeid(ID3D11DomainShader))
    {
        ID3D11DomainShader* shader = nullptr;
        DXCall(device->CreateDomainShader(byteCode->GetBufferPointer(), byteCode->GetBufferSize(),
                                          nullptr, &shader));
        return shader;
    }
    else if(typeid(T) == typeid(ID3D11GeometryShader))
    {
        ID3D11GeometryShader* shader = nullptr;
        DXCall(device->CreateGeometryShader(byteCode->GetBufferPointer(), byteCode->GetBufferSize(),
                                          nullptr, &shader));
        return shader;
    }
    else if(typeid(T) == typeid(ID3D11PixelShader))
    {
        ID3D11PixelShader* shader = nullptr;
        DXCall(device->CreatePixelShader(byteCode->GetBufferPointer(), byteCode->GetBufferSize(),
                                          nullptr, &shader));
        return shader;
    }
    else if(typeid(T) == typeid(ID3D11ComputeShader))
    {
        ID3D11ComputeShader* shader = nullptr;
        DXCall(device->CreateComputeShader(byteCode->GetBufferPointer(), byteCode->GetBufferSize(),
                                          nullptr, &shader));
        return shader;
    }

    AssertFail_("Invalid type passed to CreateShader");
    return nullptr;
}

template<typename T> void CompileShader(ID3D11Device* device, CompiledShader* shader)
{
    Assert_(shader != nullptr);
    Assert_(*shader->Type == typeid(T));

    vector<wstring> filePaths;
    D3D_SHADER_MACRO defines[CompileOptions::MaxDefines + 1];
    shader->CompileOpts.MakeDefines(defines);
    shader->ByteCode = CompileShader(shader->FilePath.c_str(), shader->FunctionName.c_str(),
                                     shader->Profile.c_str(), defines,
                                     shader->ForceOptimization, filePaths);

    shader->ShaderPtr.Attach(CreateShader<T>(device, shader->ByteCode));

    for(uint64 fileIdx = 0; fileIdx < filePaths.size(); ++ fileIdx)
    {
        const wstring& filePath = filePaths[fileIdx];
        ShaderFile* shaderFile = nullptr;
        for(uint64 shaderFileIdx = 0; shaderFileIdx < ShaderFiles.size(); ++shaderFileIdx)
        {
            if(ShaderFiles[shaderFileIdx]->FilePath == filePath)
            {
                shaderFile = ShaderFiles[shaderFileIdx];
                break;
            }
        }
        if(shaderFile == nullptr)
        {
            shaderFile = new ShaderFile(filePath);
            ShaderFiles.push_back(shaderFile);
        }

        bool containsShader = false;
        for(uint64 shaderIdx = 0; shaderIdx < shaderFile->Shaders.size(); ++shaderIdx)
        {
            if(shaderFile->Shaders[shaderIdx] == shader)
            {
                containsShader = true;
                break;
            }
        }

        if(containsShader == false)
            shaderFile->Shaders.push_back(shader);
    }
}

VertexShaderPtr CompileVSFromFile(ID3D11Device* device,
                                  const wchar* path,
                                  const char* functionName,
                                  const char* profile,
                                  const CompileOptions& compileOptions,
                                  bool forceOptimization)
{
    CompiledVertexShader* compiledShader = new CompiledVertexShader(path, functionName, profile, compileOptions, forceOptimization);
    CompileShader<ID3D11VertexShader>(device, compiledShader);
    CompiledShaders.push_back(compiledShader);

    return compiledShader;
}

PixelShaderPtr CompilePSFromFile(ID3D11Device* device,
                                 const wchar* path,
                                 const char* functionName,
                                 const char* profile,
                                 const CompileOptions& compileOptions,
                                 bool forceOptimization)
{
    CompiledPixelShader* compiledShader = new CompiledPixelShader(path, functionName, profile, compileOptions, forceOptimization);
    CompileShader<ID3D11PixelShader>(device, compiledShader);
    CompiledShaders.push_back(compiledShader);

    return compiledShader;
}

GeometryShaderPtr CompileGSFromFile(ID3D11Device* device,
                                    const wchar* path,
                                    const char* functionName,
                                    const char* profile,
                                    const CompileOptions& compileOptions,
                                    bool forceOptimization)
{
    CompiledGeometryShader* compiledShader = new CompiledGeometryShader(path, functionName, profile, compileOptions, forceOptimization);
    CompileShader<ID3D11GeometryShader>(device, compiledShader);
    CompiledShaders.push_back(compiledShader);

    return compiledShader;
}

HullShaderPtr CompileHSFromFile(ID3D11Device* device,
                                const wchar* path,
                                const char* functionName,
                                const char* profile,
                                const CompileOptions& compileOptions,
                                bool forceOptimization)
{
    CompiledHullShader* compiledShader = new CompiledHullShader(path, functionName, profile, compileOptions, forceOptimization);
    CompileShader<ID3D11HullShader>(device, compiledShader);
    CompiledShaders.push_back(compiledShader);

    return compiledShader;
}

DomainShaderPtr CompileDSFromFile(ID3D11Device* device,
                                  const wchar* path,
                                  const char* functionName,
                                  const char* profile,
                                  const CompileOptions& compileOptions,
                                  bool forceOptimization)
{
    CompiledDomainShader* compiledShader = new CompiledDomainShader(path, functionName, profile, compileOptions, forceOptimization);
    CompileShader<ID3D11DomainShader>(device, compiledShader);
    CompiledShaders.push_back(compiledShader);

    return compiledShader;
}

ComputeShaderPtr CompileCSFromFile(ID3D11Device* device,
                                   const wchar* path,
                                   const char* functionName,
                                   const char* profile,
                                   const CompileOptions& compileOptions,
                                   bool forceOptimization)
{
    CompiledComputeShader* compiledShader = new CompiledComputeShader(path, functionName, profile, compileOptions, forceOptimization);
    CompileShader<ID3D11ComputeShader>(device, compiledShader);
    CompiledShaders.push_back(compiledShader);

    return compiledShader;
}

void UpdateShaders(ID3D11Device* device)
{
    if(ShaderFiles.size() == 0)
        return;

    static uint64 currFile = 0;
    currFile = (currFile + 1) % uint64(ShaderFiles.size());

    ShaderFile* file = ShaderFiles[currFile];
    const uint64 newTimeStamp = GetFileTimestamp(file->FilePath.c_str());
    if(file->TimeStamp == 0)
    {
        file->TimeStamp = newTimeStamp;
        return;
    }

    if(file->TimeStamp < newTimeStamp)
    {
        std::printf("Hot-swapping shaders for %ls\n", file->FilePath.c_str());
        file->TimeStamp = newTimeStamp;
        for(uint64 i = 0; i < file->Shaders.size(); ++i)
        {
            // Retry a few times to avoid file conflicts with text editors
            const uint64 NumRetries = 1000;
            for(uint64 retryCount = 0; retryCount < NumRetries; ++retryCount)
            {
                try
                {
                    CompiledShader* shader = file->Shaders[i];
                    if(*shader->Type == typeid(ID3D11VertexShader))
                        CompileShader<ID3D11VertexShader>(device, shader);
                    else if(*shader->Type == typeid(ID3D11HullShader))
                        CompileShader<ID3D11HullShader>(device, shader);
                    else if(*shader->Type == typeid(ID3D11DomainShader))
                        CompileShader<ID3D11DomainShader>(device, shader);
                    else if(*shader->Type == typeid(ID3D11GeometryShader))
                        CompileShader<ID3D11GeometryShader>(device, shader);
                    else if(*shader->Type == typeid(ID3D11PixelShader))
                        CompileShader<ID3D11PixelShader>(device, shader);
                    else if(*shader->Type == typeid(ID3D11ComputeShader))
                        CompileShader<ID3D11ComputeShader>(device, shader);
                    else
                        AssertFail_("Invalid shader type");

                    break;
                }
                catch(Win32Exception& exception)
                {
                    if(retryCount == NumRetries - 1)
                        throw exception;
                    Sleep(15);
                }
            }
        }
    }
}

void ShutdownShaders()
{
    for(uint64 i = 0; i < ShaderFiles.size(); ++i)
        delete ShaderFiles[i];

    for(uint64 i = 0; i < CompiledShaders.size(); ++i)
        delete CompiledShaders[i];
}

// == CompileOptions ==============================================================================

CompileOptions::CompileOptions()
{
    Reset();
}

void CompileOptions::Add(const std::string& name, uint32 value)
{
    Assert_(numDefines < MaxDefines);

    nameOffsets[numDefines] = bufferIdx;
    for(uint32 i = 0; i < name.length(); ++i)
        buffer[bufferIdx++] = name[i];
    ++bufferIdx;

    std::string stringVal = ToAnsiString(value);
    defineOffsets[numDefines] = bufferIdx;
    for(uint32 i = 0; i < stringVal.length(); ++i)
        buffer[bufferIdx++] = stringVal[i];
    ++bufferIdx;

    ++numDefines;
}

void CompileOptions::Reset()
{
    numDefines = 0;
    bufferIdx = 0;

    for(uint32 i = 0; i < MaxDefines; ++i)
    {
        nameOffsets[i] = 0xFFFFFFFF;
        defineOffsets[i] = 0xFFFFFFFF;
    }

    ZeroMemory(buffer, BufferSize);
}

void CompileOptions::MakeDefines(D3D_SHADER_MACRO defines[MaxDefines + 1]) const
{
    for(uint32 i = 0; i < numDefines; ++i)
    {
        defines[i].Name = buffer + nameOffsets[i];
        defines[i].Definition = buffer + defineOffsets[i];
    }

    defines[numDefines].Name = nullptr;
    defines[numDefines].Definition = nullptr;
}

}