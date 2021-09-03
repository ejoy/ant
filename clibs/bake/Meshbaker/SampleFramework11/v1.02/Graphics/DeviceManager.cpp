//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "DeviceManager.h"
#include "..\\Exceptions.h"
#include "..\\Utility.h"

using std::wstring;

#if _DEBUG
    #define UseDebugDevice_ 1
    #define BreakOnDXError_ (UseDebugDevice_ && 1)
#else
    #define UseDebugDevice_ 0
    #define BreakOnDXError_ 0
#endif

namespace SampleFramework11
{

DeviceManager::DeviceManager()  :  backBufferFormat(DXGI_FORMAT_R8G8B8A8_UNORM_SRGB),
                                   backBufferWidth(1280),
                                   backBufferHeight(720),
                                   msCount(1),
                                   msQuality(0),
                                   fullScreen(false),
                                   featureLevel(D3D_FEATURE_LEVEL_11_0),
                                   minFeatureLevel(D3D_FEATURE_LEVEL_10_0),
                                   vsync(true),
                                   numVSYNCIntervals(1)
{
    refreshRate.Numerator = 60;
    refreshRate.Denominator = 1;

    // Try to figure out if we should default to 1280x720 or 1920x1080
    POINT point;
    point.x = 0;
    point.y = 0;
    HMONITOR monitor = MonitorFromPoint(point, MONITOR_DEFAULTTOPRIMARY);
    if(monitor != 0)
    {
        MONITORINFOEX info;
        ZeroMemory(&info, sizeof(info));
        info.cbSize = sizeof(MONITORINFOEX);
        if(GetMonitorInfo(monitor, &info) != 0)
        {
            int32 width = info.rcWork.right - info.rcWork.left;
            int32 height = info.rcWork.bottom - info.rcWork.top;
            if(width > 1920 && height > 1080)
            {
                backBufferWidth = 1920;
                backBufferHeight = 1080;
            }
        }
    }
}

DeviceManager::~DeviceManager()
{
    if(immediateContext)
    {
        immediateContext->ClearState();
        immediateContext->Flush();
    }
}

void DeviceManager::Initialize(HWND outputWindow)
{
    CheckForSuitableOutput();

    DXGI_SWAP_CHAIN_DESC desc;
    ZeroMemory(&desc, sizeof(DXGI_SWAP_CHAIN_DESC));

    if(fullScreen)
    {
        PrepareFullScreenSettings();
    }
    else
    {
        refreshRate.Numerator = 60;
        refreshRate.Denominator = 1;
    }

    desc.BufferCount = 2;
    desc.BufferDesc.Format = backBufferFormat;
    desc.BufferDesc.Width = backBufferWidth;
    desc.BufferDesc.Height = backBufferHeight;
    desc.BufferDesc.Scaling = DXGI_MODE_SCALING_UNSPECIFIED;
    desc.BufferDesc.ScanlineOrdering = DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED;
    desc.BufferDesc.RefreshRate = refreshRate;
    desc.SampleDesc.Count = msCount;
    desc.SampleDesc.Quality = msQuality;
    desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH;
    desc.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
    desc.OutputWindow = outputWindow;
    desc.Windowed = !fullScreen;

    uint32 flags = D3D11_CREATE_DEVICE_SINGLETHREADED;
    #if UseDebugDevice_
        flags |= D3D11_CREATE_DEVICE_DEBUG;
    #endif

    DXCall(D3D11CreateDeviceAndSwapChain(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, flags,
                                         NULL, 0, D3D11_SDK_VERSION, &desc, &swapChain,
                                         &device, NULL, &immediateContext));

    featureLevel = device->GetFeatureLevel();

    if(featureLevel < minFeatureLevel)
    {
        wstring majorLevel = ToString<int>(minFeatureLevel >> 12);
        wstring minorLevel = ToString<int>((minFeatureLevel >> 8) & 0xF);
        throw Exception(L"The device doesn't support the minimum feature level required to run this sample (DX" + majorLevel + L"." + minorLevel + L")");
    }

    if(BreakOnDXError_ && D3DPERF_GetStatus() == 0)
    {
        ID3D11InfoQueuePtr infoQueue;
        DXCall(device->QueryInterface(__uuidof(ID3D11InfoQueue), reinterpret_cast<void**>(&infoQueue)));
        infoQueue->SetBreakOnSeverity(D3D11_MESSAGE_SEVERITY_WARNING, TRUE);
        infoQueue->SetBreakOnSeverity(D3D11_MESSAGE_SEVERITY_ERROR, TRUE);
    }

    AfterReset();
}

void DeviceManager::AfterReset()
{
    DXCall(swapChain->GetBuffer(0, __uuidof(bbTexture), reinterpret_cast<void**>(&bbTexture)));
    DXCall(device->CreateRenderTargetView(bbTexture, NULL, &bbRTView));

    // Set default render targets
    immediateContext->OMSetRenderTargets(1, &(bbRTView.GetInterfacePtr()), NULL);

    // Setup the viewport
    D3D11_VIEWPORT vp;
    vp.Width = static_cast<float>(backBufferWidth);
    vp.Height = static_cast<float>(backBufferHeight);
    vp.MinDepth = 0.0f;
    vp.MaxDepth = 1.0f;
    vp.TopLeftX = 0;
    vp.TopLeftY = 0;
    immediateContext->RSSetViewports(1, &vp);
}

void DeviceManager::CheckForSuitableOutput()
{
    HRESULT hr = CreateDXGIFactory1(__uuidof(IDXGIFactory1), reinterpret_cast<void**>(&factory));
    if(FAILED(hr))
        throw Exception(L"Unable to create a DXGI 1.1 device.\n "
                        L"Make sure that your OS and driver support DirectX 11");

    // Look for an adapter that supports D3D11
    IDXGIAdapter1Ptr curAdapter;
    uint32 adapterIdx = 0;
    LARGE_INTEGER umdVersion;
    while(!adapter && SUCCEEDED(factory->EnumAdapters1(0, &adapter)))
        if(SUCCEEDED(adapter->CheckInterfaceSupport(__uuidof(ID3D11Device), &umdVersion)))
            adapter = curAdapter;

    if(!adapter)
        throw Exception(L"Unable to locate a DXGI 1.1 adapter that supports a D3D11 device.\n"
                        L"Make sure that your OS and driver support DirectX 11");

    // We'll just use the first output
    DXCall(adapter->EnumOutputs(0, &output));
}

void DeviceManager::PrepareFullScreenSettings()
{
    Assert_(output);

    // Have the Output look for the closest matching mode
    DXGI_MODE_DESC desiredMode;
    desiredMode.Format = backBufferFormat;
    desiredMode.Width = backBufferWidth;
    desiredMode.Height = backBufferHeight;
    desiredMode.RefreshRate.Numerator = 0;
    desiredMode.RefreshRate.Denominator = 0;
    desiredMode.Scaling = DXGI_MODE_SCALING_UNSPECIFIED;
    desiredMode.ScanlineOrdering = DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED;

    DXGI_MODE_DESC closestMatch;
    DXCall(output->FindClosestMatchingMode(&desiredMode, &closestMatch, device.GetInterfacePtr()));

    backBufferFormat = closestMatch.Format;
    backBufferWidth = closestMatch.Width;
    backBufferHeight = closestMatch.Height;
    refreshRate = closestMatch.RefreshRate;
}

void DeviceManager::Reset()
{
    Assert_(swapChain);

    // Release all references
    if(bbTexture)
        bbTexture.Release();

    if(bbRTView)
        bbRTView.Release();

    immediateContext->ClearState();

    if(fullScreen)
        PrepareFullScreenSettings();
    else
    {
        refreshRate.Numerator = 60;
        refreshRate.Denominator = 1;
    }

    DXCall(swapChain->SetFullscreenState(fullScreen, NULL));

    DXCall(swapChain->ResizeBuffers(2, backBufferWidth, backBufferHeight,
                                    backBufferFormat, DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH));

    if(fullScreen)
    {
        DXGI_MODE_DESC mode;
        mode.Format = backBufferFormat;
        mode.Width = backBufferWidth;
        mode.Height = backBufferHeight;
        mode.RefreshRate.Numerator = 0;
        mode.RefreshRate.Denominator = 0;
        mode.Scaling = DXGI_MODE_SCALING_UNSPECIFIED;
        mode.ScanlineOrdering = DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED;
        DXCall(swapChain->ResizeTarget(&mode));
    }

    AfterReset();
}

void DeviceManager::Present()
{
    Assert_(device);

    uint32 interval = vsync ? numVSYNCIntervals : 0;
    DXCall(swapChain->Present(interval, 0));
}

}