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

// Device
_COM_SMARTPTR_TYPEDEF(ID3D11Device, __uuidof(ID3D11Device));
_COM_SMARTPTR_TYPEDEF(ID3D11DeviceContext, __uuidof(ID3D11DeviceContext));
_COM_SMARTPTR_TYPEDEF(ID3D11DeviceChild, __uuidof(ID3D11DeviceChild));
_COM_SMARTPTR_TYPEDEF(ID3D11Query, __uuidof(ID3D11Query));
_COM_SMARTPTR_TYPEDEF(ID3D11CommandList, __uuidof(ID3D11CommandList));
_COM_SMARTPTR_TYPEDEF(ID3D11Counter, __uuidof(ID3D11Counter));
_COM_SMARTPTR_TYPEDEF(ID3D11InputLayout, __uuidof(ID3D11InputLayout));
_COM_SMARTPTR_TYPEDEF(ID3D11Predicate, __uuidof(ID3D11Predicate));
_COM_SMARTPTR_TYPEDEF(ID3D11Asynchronous, __uuidof(ID3D11Asynchronous));
_COM_SMARTPTR_TYPEDEF(ID3D11InfoQueue, __uuidof(ID3D11InfoQueue));
_COM_SMARTPTR_TYPEDEF(ID3D11Debug, __uuidof(ID3D11Debug));

// States
_COM_SMARTPTR_TYPEDEF(ID3D11BlendState, __uuidof(ID3D11BlendState));
_COM_SMARTPTR_TYPEDEF(ID3D11DepthStencilState, __uuidof(ID3D11DepthStencilState));
_COM_SMARTPTR_TYPEDEF(ID3D11RasterizerState, __uuidof(ID3D11RasterizerState));
_COM_SMARTPTR_TYPEDEF(ID3D11SamplerState, __uuidof(ID3D11SamplerState));

// Resources
_COM_SMARTPTR_TYPEDEF(ID3D11Resource, __uuidof(ID3D11Resource));
_COM_SMARTPTR_TYPEDEF(ID3D11Texture1D, __uuidof(ID3D11Texture1D));
_COM_SMARTPTR_TYPEDEF(ID3D11Texture2D, __uuidof(ID3D11Texture2D));
_COM_SMARTPTR_TYPEDEF(ID3D11Texture3D, __uuidof(ID3D11Texture3D));
_COM_SMARTPTR_TYPEDEF(ID3D11Buffer, __uuidof(ID3D11Buffer));

// Views
_COM_SMARTPTR_TYPEDEF(ID3D11View, __uuidof(ID3D11View));
_COM_SMARTPTR_TYPEDEF(ID3D11RenderTargetView, __uuidof(ID3D11RenderTargetView));
_COM_SMARTPTR_TYPEDEF(ID3D11ShaderResourceView, __uuidof(ID3D11ShaderResourceView));
_COM_SMARTPTR_TYPEDEF(ID3D11DepthStencilView, __uuidof(ID3D11DepthStencilView));
_COM_SMARTPTR_TYPEDEF(ID3D11UnorderedAccessView, __uuidof(ID3D11UnorderedAccessView));

// Shaders
_COM_SMARTPTR_TYPEDEF(ID3D11ComputeShader, __uuidof(ID3D11ComputeShader));
_COM_SMARTPTR_TYPEDEF(ID3D11DomainShader, __uuidof(ID3D11DomainShader));
_COM_SMARTPTR_TYPEDEF(ID3D11GeometryShader, __uuidof(ID3D11GeometryShader));
_COM_SMARTPTR_TYPEDEF(ID3D11HullShader, __uuidof(ID3D11HullShader));
_COM_SMARTPTR_TYPEDEF(ID3D11PixelShader, __uuidof(ID3D11PixelShader));
_COM_SMARTPTR_TYPEDEF(ID3D11VertexShader, __uuidof(ID3D11VertexShader));
_COM_SMARTPTR_TYPEDEF(ID3D11ClassInstance, __uuidof(ID3D11ClassInstance));
_COM_SMARTPTR_TYPEDEF(ID3D11ClassLinkage, __uuidof(ID3D11ClassLinkage));
_COM_SMARTPTR_TYPEDEF(ID3D11ShaderReflection, IID_ID3D11ShaderReflection);
_COM_SMARTPTR_TYPEDEF(ID3D11ShaderReflectionConstantBuffer, IID_ID3D11ShaderReflectionConstantBuffer);
_COM_SMARTPTR_TYPEDEF(ID3D11ShaderReflectionType, IID_ID3D11ShaderReflectionType);
_COM_SMARTPTR_TYPEDEF(ID3D11ShaderReflectionVariable, IID_ID3D11ShaderReflectionVariable);

// D3D10
_COM_SMARTPTR_TYPEDEF(ID3D10Blob, IID_ID3D10Blob);
typedef ID3D10BlobPtr ID3DBlobPtr;

// DXGI
_COM_SMARTPTR_TYPEDEF(IDXGISwapChain, __uuidof(IDXGISwapChain));
_COM_SMARTPTR_TYPEDEF(IDXGIAdapter, __uuidof(IDXGIAdapter));
_COM_SMARTPTR_TYPEDEF(IDXGIAdapter1, __uuidof(IDXGIAdapter1));
_COM_SMARTPTR_TYPEDEF(IDXGIDevice, __uuidof(IDXGIDevice));
_COM_SMARTPTR_TYPEDEF(IDXGIDevice1, __uuidof(IDXGIDevice1));
_COM_SMARTPTR_TYPEDEF(IDXGIDeviceSubObject, __uuidof(IDXGIDeviceSubObject));
_COM_SMARTPTR_TYPEDEF(IDXGIFactory, __uuidof(IDXGIFactory));
_COM_SMARTPTR_TYPEDEF(IDXGIFactory1, __uuidof(IDXGIFactory1));
_COM_SMARTPTR_TYPEDEF(IDXGIKeyedMutex, __uuidof(IDXGIKeyedMutex));
_COM_SMARTPTR_TYPEDEF(IDXGIObject, __uuidof(IDXGIObject));
_COM_SMARTPTR_TYPEDEF(IDXGIOutput, __uuidof(IDXGIOutput));
_COM_SMARTPTR_TYPEDEF(IDXGIResource, __uuidof(IDXGIResource));
_COM_SMARTPTR_TYPEDEF(IDXGISurface1, __uuidof(IDXGISurface1));

}
